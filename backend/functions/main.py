import asyncio
import json
import os
from firebase_admin import initialize_app, firestore, auth
from firebase_functions import firestore_fn, https_fn, scheduler_fn
from google.cloud import firestore as gcf

initialize_app()

_GCP_PROJECT  = "projdoc-aab8e"
_GCP_LOCATION = "us-central1"
_TASK_QUEUE   = "report-queue"


def _validate_job(job: dict, jid: str, db) -> tuple:
    """
    Returns (is_valid: bool, reason: str).
    Checks:
      1. uid is a real Firebase Auth user
      2. All required fields are present and non-empty
      3. Max 2 jobs in pending/processing/queued state per user (abuse guard)
      4. User has a generate_credit (payment gate) — atomically decrements on success
    """
    uid = job.get("uid", "").strip()

    if not uid:
        return False, "missing_uid"

    try:
        auth.get_user(uid)
    except Exception:
        return False, "invalid_uid"

    for field in ("title", "description", "domain", "tech_stack", "student_name", "batch_year", "client"):
        if not str(job.get(field, "")).strip():
            return False, f"missing_field:{field}"

    active = list(
        db.collection("jobs")
          .where("uid", "==", uid)
          .where("status", "in", ["pending", "queued", "processing"])
          .stream()
    )
    active_others = [j for j in active if j.id != jid]
    if len(active_others) >= 2:
        return False, "rate_limit:too_many_active_jobs"

    # Atomically check and deduct one generate credit
    user_ref = db.collection("users").document(uid)

    @gcf.transactional
    def _deduct_credit(transaction, ref):
        snap    = ref.get(transaction=transaction)
        data    = snap.to_dict() or {}
        credits = int(data.get("generate_credits", 0))
        if credits <= 0:
            return False
        transaction.update(ref, {"generate_credits": credits - 1})
        return True

    if not _deduct_credit(db.transaction(), user_ref):
        return False, "payment_required"

    return True, "ok"


# ── Test ping ─────────────────────────────────────────────────────────────────

@https_fn.on_request(secrets=["ANTHROPIC_API_KEY"])
def ping_llm(req: https_fn.Request) -> https_fn.Response:
    from report_agent import run_test_ping
    try:
        result = run_test_ping()
        return https_fn.Response(
            json.dumps(result),
            status=200,
            content_type="application/json",
        )
    except Exception as e:
        return https_fn.Response(
            json.dumps({"status": "error", "error": str(e)}),
            status=500,
            content_type="application/json",
        )


# ── Firestore trigger — validates job then enqueues to Cloud Tasks ────────────

@firestore_fn.on_document_created(
    document      = "jobs/{job_id}",
    timeout_sec   = 30,
    memory        = 256,
    max_instances = 100,
    min_instances = 0,
)
def generate_report(event: firestore_fn.Event) -> None:
    from google.cloud import tasks_v2

    job = event.data.to_dict()
    jid = event.params["job_id"]
    db  = firestore.client()
    job["job_id"] = jid

    valid, reason = _validate_job(job, jid, db)
    if not valid:
        # Refund credit if payment_required wasn't the reason (credit was already deducted)
        db.collection("jobs").document(jid).update({
            "status": "failed",
            "error" : f"rejected:{reason}",
        })
        print(f"[SECURITY] Job {jid} rejected: {reason}")
        return

    function_url = (
        f"https://{_GCP_LOCATION}-{_GCP_PROJECT}.cloudfunctions.net/process_report_task"
    )
    try:
        client = tasks_v2.CloudTasksClient()
        parent = client.queue_path(_GCP_PROJECT, _GCP_LOCATION, _TASK_QUEUE)
        task = {
            "http_request": {
                "http_method": tasks_v2.HttpMethod.POST,
                "url": function_url,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"job_id": jid}).encode(),
                "oidc_token": {
                    "service_account_email": f"{_GCP_PROJECT}@appspot.gserviceaccount.com"
                },
            }
        }
        client.create_task(request={"parent": parent, "task": task})
    except Exception as e:
        # Refund the credit so user is not penalised for infra failure
        db.collection("users").document(job["uid"]).update(
            {"generate_credits": gcf.Increment(1)}
        )
        db.collection("jobs").document(jid).update({
            "status": "failed",
            "error" : f"queue_error:{e}",
        })
        print(f"[QUEUE] Failed to enqueue job {jid}, credit refunded: {e}")
        return

    db.collection("jobs").document(jid).update({"status": "queued"})
    print(f"[QUEUE] Job {jid} enqueued to {_TASK_QUEUE}")


# ── Cloud Tasks worker — does the actual report generation ───────────────────

@https_fn.on_request(
    timeout_sec   = 540,
    memory        = 512,
    max_instances = 10,
    secrets       = ["ANTHROPIC_API_KEY", "GMAIL_USER", "GMAIL_APP_PASSWORD"]
)
def process_report_task(req: https_fn.Request) -> https_fn.Response:
    if not req.headers.get("X-CloudTasks-QueueName"):
        return https_fn.Response("Forbidden", status=403)

    payload = req.get_json(silent=True) or {}
    jid = payload.get("job_id")
    if not jid:
        return https_fn.Response("Bad Request: missing job_id", status=400)

    db  = firestore.client()
    doc = db.collection("jobs").document(jid).get()
    if not doc.exists:
        return https_fn.Response("Not Found", status=404)

    job = doc.to_dict()
    job["job_id"] = jid

    # Idempotency guard — Cloud Tasks may retry; skip jobs already finished
    if job.get("status") in ("done", "expired"):
        print(f"[WORKER] Job {jid} already completed (status={job.get('status')}), skipping retry")
        return https_fn.Response("Already processed", status=200)

    db.collection("jobs").document(jid).update({"status": "processing"})
    try:
        from report_agent import run_report_agent
        asyncio.run(run_report_agent(job))

        # Schedule expiry reminder notifications via Cloud Tasks
        try:
            import datetime
            from google.cloud import tasks_v2 as _tasks
            from google.protobuf import timestamp_pb2
            _tc     = _tasks.CloudTasksClient()
            _parent = _tc.queue_path(_GCP_PROJECT, _GCP_LOCATION, _TASK_QUEUE)
            _notify_url = (
                f"https://{_GCP_LOCATION}-{_GCP_PROJECT}.cloudfunctions.net"
                f"/send_expiry_reminder"
            )
            for hours_before, delay_hours in [(8, 16), (6, 18)]:
                _sched = datetime.datetime.now(tz=datetime.timezone.utc) + datetime.timedelta(hours=delay_hours)
                _ts = timestamp_pb2.Timestamp()
                _ts.FromDatetime(_sched)
                _tc.create_task(request={"parent": _parent, "task": {
                    "http_request": {
                        "http_method": _tasks.HttpMethod.POST,
                        "url"        : _notify_url,
                        "headers"    : {"Content-Type": "application/json"},
                        "body"       : json.dumps({"job_id": jid, "hours_remaining": hours_before}).encode(),
                        "oidc_token" : {"service_account_email": f"{_GCP_PROJECT}@appspot.gserviceaccount.com"},
                    },
                    "schedule_time": _ts,
                }})
        except Exception as ne:
            print(f"[NOTIFY] Failed to schedule reminders for {jid}: {ne}")

        return https_fn.Response("OK", status=200)
    except Exception as e:
        db.collection("jobs").document(jid).update({
            "status": "failed",
            "error" : str(e),
        })
        return https_fn.Response(str(e), status=500)


# ── Admin: set custom claim ───────────────────────────────────────────────────

@https_fn.on_call(secrets=["ADMIN_BOOTSTRAP_TOKEN"])
def set_admin_claim(req: https_fn.CallableRequest):
    target_uid      = (req.data or {}).get("uid", "").strip()
    bootstrap_token = (req.data or {}).get("bootstrap_token", "")
    caller_uid      = req.auth.uid if req.auth else None
    stored_token = (os.environ.get("ADMIN_BOOTSTRAP_TOKEN") or "").strip()
    sent_token = (bootstrap_token or "").strip()
    if not target_uid:
        return {"error": "missing_uid"}

    # Allow either: valid bootstrap token OR existing admin caller
    if sent_token  and sent_token  == stored_token:
        pass  # bootstrap path — no caller check needed
    else:
        if not caller_uid:
            return {"error": "unauthorized"}
        try:
            caller = auth.get_user(caller_uid)
            if not (caller.custom_claims or {}).get("admin"):
                return {"error": "unauthorized"}
        except Exception:
            return {"error": "unauthorized"}

    auth.set_custom_user_claims(target_uid, {"admin": True})
    print(f"[ADMIN] Set admin claim on uid={target_uid}")
    return {"success": True}


# ── Admin: stats dashboard data ───────────────────────────────────────────────

_CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
}

@https_fn.on_request()
def admin_get_stats(req: https_fn.Request) -> https_fn.Response:
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=_CORS_HEADERS)

    auth_header = req.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return https_fn.Response(
            json.dumps({"error": "unauthorized"}), status=401,
            content_type="application/json", headers=_CORS_HEADERS,
        )

    id_token = auth_header.split("Bearer ", 1)[1]
    try:
        decoded = auth.verify_id_token(id_token)
        if not decoded.get("admin"):
            return https_fn.Response(
                json.dumps({"error": "forbidden"}), status=403,
                content_type="application/json", headers=_CORS_HEADERS,
            )
    except Exception:
        return https_fn.Response(
            json.dumps({"error": "unauthorized"}), status=401,
            content_type="application/json", headers=_CORS_HEADERS,
        )

    db       = firestore.client()
    all_docs = list(
        db.collection("jobs")
          .order_by("created_at", direction="DESCENDING")
          .limit(200)
          .stream()
    )

    jobs_data = []
    for doc in all_docs:
        j = {"id": doc.id}
        for k, v in doc.to_dict().items():
            if hasattr(v, "isoformat"):
                j[k] = v.isoformat()
            else:
                j[k] = v
        jobs_data.append(j)

    status_counts: dict = {}
    for j in jobs_data:
        s = j.get("status", "unknown")
        status_counts[s] = status_counts.get(s, 0) + 1

    return https_fn.Response(
        json.dumps({
            "jobs"   : jobs_data,
            "counts" : status_counts,
            "total"  : len(jobs_data),
        }),
        status=200, headers=_CORS_HEADERS,
        content_type="application/json",
    )


# ── Test: assembler + delivery without LLM ────────────────────────────────────

@https_fn.on_request(
    timeout_sec = 120,
    memory      = 512,
    secrets     = ["GMAIL_USER", "GMAIL_APP_PASSWORD"]
)
def test_pipeline(req: https_fn.Request) -> https_fn.Response:
    """
    Runs assembler_node + delivery_node with dummy chapters.
    No LLM calls. Protected by admin Bearer token.
    POST /test_pipeline  with Authorization: Bearer <id_token>
    """
    from report_agent import assembler_node, delivery_node, CHAPTER_NAMES

    auth_header = req.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return https_fn.Response(json.dumps({"error": "unauthorized"}),
                                 status=401, content_type="application/json")
    try:
        decoded = auth.verify_id_token(auth_header.split("Bearer ", 1)[1])
        if not decoded.get("admin"):
            return https_fn.Response(json.dumps({"error": "forbidden"}),
                                     status=403, content_type="application/json")
    except Exception:
        return https_fn.Response(json.dumps({"error": "unauthorized"}),
                                 status=401, content_type="application/json")

    DUMMY = (
        "This chapter provides a comprehensive overview of the system. "
        "The proposed solution leverages modern technologies to address challenges.\n\n"
        "| Component | Technology | Purpose |\n"
        "| Frontend | React.js | User Interface |\n"
        "| Backend | Flask | API Server |\n"
        "| Database | MySQL | Data Storage |\n\n"
        "Testing was conducted across multiple environments and use cases. "
        "Unit tests verified individual component behavior and edge cases. "
        "Performance benchmarks showed response times under 200 milliseconds.\n\n"
    ) * 4

    job = {
        "job_id"            : "test-pipeline-001",
        "uid"               : decoded["uid"],
        "title"             : "Smart Attendance System using Face Recognition",
        "description"       : "A web-based attendance system using OpenCV and Flask.",
        "domain"            : "CSE / IT",
        "tech_stack"        : "Python, OpenCV, Flask, MySQL",
        "student_name"      : "Test Student",
        "batch_year"        : "2024-2025",
        "client"            : "LNCT Bhopal",
        "doc_color_hex"     : "#6C63FF",
        "notification_email": "",
        "fcm_token"         : None,
    }

    db = firestore.client()
    db.collection("test_jobs").document(job["job_id"]).set({
        "status": "processing", "title": job["title"], "uid": job["uid"],
    })

    state = {
        "job"            : job,
        "chapter_plan"   : {},
        "context_summary": "",
        "chapters"       : {n: DUMMY for n in CHAPTER_NAMES},
        "chapter_status" : {n: "done" for n in CHAPTER_NAMES},
        "retry_count"    : {},
        "quality_flags"  : {},
        "failed_chapters": [],
        "docx_bytes"     : b"",
        "viva_content"   : "Q1: What is face recognition?\nQ2: How does OpenCV work?\nQ3: System accuracy?",
        "summary_content": "Smart attendance system using face recognition via OpenCV and Flask.",
        "drive_url"      : "",
        "error"          : "",
    }

    state = assembler_node(state)
    if not state["docx_bytes"]:
        return https_fn.Response(json.dumps({"error": "assembler produced no output"}),
                                 status=500, content_type="application/json")

    state = delivery_node(state)
    if state.get("error"):
        return https_fn.Response(json.dumps({"error": state["error"]}),
                                 status=500, content_type="application/json")

    db.collection("test_jobs").document(job["job_id"]).delete()
    return https_fn.Response(
        json.dumps({"status": "ok", "download_url": state["drive_url"]}),
        status=200, content_type="application/json",
    )


# ── Admin: add generate credit to a user by email ────────────────────────────

@https_fn.on_request()
def admin_add_credit(req: https_fn.Request) -> https_fn.Response:
    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=_CORS_HEADERS)

    auth_header = req.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return https_fn.Response(json.dumps({"error": "unauthorized"}), status=401,
                                 content_type="application/json", headers=_CORS_HEADERS)
    try:
        decoded = auth.verify_id_token(auth_header.split("Bearer ", 1)[1])
        if not decoded.get("admin"):
            return https_fn.Response(json.dumps({"error": "forbidden"}), status=403,
                                     content_type="application/json", headers=_CORS_HEADERS)
    except Exception:
        return https_fn.Response(json.dumps({"error": "unauthorized"}), status=401,
                                 content_type="application/json", headers=_CORS_HEADERS)

    body  = req.get_json(silent=True) or {}
    email = (body.get("email") or "").strip().lower()
    if not email:
        return https_fn.Response(json.dumps({"error": "missing_email"}), status=400,
                                 content_type="application/json", headers=_CORS_HEADERS)
    try:
        user_record = auth.get_user_by_email(email)
    except Exception:
        return https_fn.Response(json.dumps({"error": "user_not_found"}), status=404,
                                 content_type="application/json", headers=_CORS_HEADERS)

    uid = user_record.uid
    db  = firestore.client()
    db.collection("users").document(uid).set(
        {"generate_credits": gcf.Increment(1)}, merge=True
    )
    print(f"[ADMIN] Credit added to uid={uid} email={email} by admin={decoded.get('uid')}")
    return https_fn.Response(
        json.dumps({"success": True, "uid": uid, "email": email}),
        status=200, content_type="application/json", headers=_CORS_HEADERS,
    )


# ── Expiry reminder — called by Cloud Tasks 16h and 18h after report completes ─

@https_fn.on_request(timeout_sec=30, memory=256)
def send_expiry_reminder(req: https_fn.Request) -> https_fn.Response:
    if not req.headers.get("X-CloudTasks-QueueName"):
        return https_fn.Response("Forbidden", status=403)

    payload         = req.get_json(silent=True) or {}
    jid             = payload.get("job_id")
    hours_remaining = payload.get("hours_remaining", 6)
    if not jid:
        return https_fn.Response("Bad Request", status=400)

    db  = firestore.client()
    doc = db.collection("jobs").document(jid).get()
    if not doc.exists:
        return https_fn.Response("OK", status=200)

    job = doc.to_dict() or {}
    if job.get("status") != "done" or job.get("downloaded_at"):
        return https_fn.Response("OK", status=200)

    fcm_token = job.get("fcm_token")
    if not fcm_token:
        return https_fn.Response("OK", status=200)

    from firebase_admin import messaging
    try:
        messaging.send(messaging.Message(
            token=fcm_token,
            notification=messaging.Notification(
                title=f"⏰ {hours_remaining} hours left to download!",
                body=f"Your report '{job.get('title', '')}' expires soon. Download now!",
            ),
            data={"job_id": jid, "download_url": job.get("download_url", "")},
        ))
        print(f"[NOTIFY] Sent {hours_remaining}h reminder for job {jid}")
    except Exception as e:
        print(f"[NOTIFY] FCM failed for job {jid}: {e}")

    return https_fn.Response("OK", status=200)


# ── Razorpay payment webhook — grants generate credit on successful payment ───

@https_fn.on_request(secrets=["RAZORPAY_WEBHOOK_SECRET"])
def razorpay_webhook(req: https_fn.Request) -> https_fn.Response:
    import hmac
    import hashlib

    raw_body  = req.get_data()
    signature = req.headers.get("X-Razorpay-Signature", "")
    secret    = (os.environ.get("RAZORPAY_WEBHOOK_SECRET") or "").encode()

    expected = hmac.new(secret, raw_body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature):
        print("[WEBHOOK] Razorpay signature mismatch")
        return https_fn.Response("Unauthorized", status=401)

    payload = req.get_json(silent=True) or {}
    event   = payload.get("event", "")

    if event != "payment_link.paid":
        return https_fn.Response("OK", status=200)

    pl_entity  = (payload.get("payload", {}).get("payment_link", {}) or {}).get("entity", {})
    pay_entity = (payload.get("payload", {}).get("payment", {}) or {}).get("entity", {})
    customer   = pl_entity.get("customer", {}) or {}
    email      = (customer.get("email") or pay_entity.get("email") or "").strip().lower()
    amount     = int(pay_entity.get("amount", 0))  # paise

    if not email:
        print("[WEBHOOK] No customer email in payload")
        return https_fn.Response("OK", status=200)

    if amount != 10000:
        print(f"[WEBHOOK] Unexpected amount {amount} paise — ignoring")
        return https_fn.Response("OK", status=200)

    # Prefer UID from notes (set by create_payment_link), fall back to email lookup
    notes = pl_entity.get("notes", {}) or pay_entity.get("notes", {}) or {}
    uid   = notes.get("firebase_uid", "").strip()
    if not uid:
        try:
            uid = auth.get_user_by_email(email).uid
        except Exception as e:
            print(f"[WEBHOOK] No Firebase user for email={email}: {e}")
            return https_fn.Response("OK", status=200)
    payment_id = pay_entity.get("id", "unknown")
    db         = firestore.client()

    # Idempotency — ignore duplicate webhook deliveries
    if db.collection("payments").document(payment_id).get().exists:
        print(f"[WEBHOOK] Duplicate payment {payment_id} — skipping")
        return https_fn.Response("OK", status=200)

    db.collection("users").document(uid).set(
        {"generate_credits": gcf.Increment(1)},
        merge=True,
    )
    db.collection("payments").document(payment_id).set({
        "uid"        : uid,
        "email"      : email,
        "amount"     : amount,
        "payment_id" : payment_id,
        "event"      : event,
        "created_at" : gcf.SERVER_TIMESTAMP,
    })

    print(f"[WEBHOOK] Credit granted uid={uid} payment={payment_id}")
    return https_fn.Response("OK", status=200)


# ── Daily cleanup — delete expired report files from Firebase Storage ─────────

@scheduler_fn.on_schedule(
    schedule  = "every 24 hours",
    timezone  = "Asia/Kolkata",
    memory    = 256,
    timeout_sec = 300,
)
def cleanup_expired_reports(event: scheduler_fn.ScheduledEvent) -> None:
    from firebase_admin import storage
    from datetime import datetime, timezone

    db      = firestore.client()
    bucket  = storage.bucket()
    now     = datetime.now(tz=timezone.utc)
    deleted = 0
    errors  = 0

    expired_jobs = (
        db.collection("jobs")
          .where("status", "==", "done")
          .where("expires_at", "<=", now)
          .limit(200)
          .stream()
    )

    for doc in expired_jobs:
        jid  = doc.id
        data = doc.to_dict() or {}

        # Delete the file from Firebase Storage
        try:
            blobs = list(bucket.list_blobs(prefix=f"reports/{jid}/"))
            for blob in blobs:
                blob.delete()
                print(f"[CLEANUP] Deleted {blob.name}")
            deleted += len(blobs)
        except Exception as e:
            print(f"[CLEANUP] Error deleting storage for job {jid}: {e}")
            errors += 1
            continue

        # Clear download URL in Firestore
        db.collection("jobs").document(jid).update({
            "download_url": "",
            "status"      : "expired",
        })

    print(f"[CLEANUP] Done — deleted files for {deleted} blobs, {errors} errors")
