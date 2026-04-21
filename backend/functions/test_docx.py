"""
Test assembler_node + delivery_node locally — no LLM calls.
Uploads real ZIP to Firebase Storage and prints a signed download URL.

Requirements:
  pip install python-docx firebase-admin google-auth google-cloud-storage
  gcloud auth application-default login   (run once)

Run: python test_docx.py
"""
import io, sys, os, zipfile

# ── Init Firebase with application default credentials ────────────────────────
import firebase_admin
from firebase_admin import credentials, firestore, storage, messaging

firebase_admin.initialize_app(options={
    "storageBucket": "projdoc-aab8e.firebasestorage.app",
    "projectId"    : "projdoc-aab8e",
})

from report_agent import assembler_node, delivery_node, CHAPTER_NAMES

# ── Dummy job ──────────────────────────────────────────────────────────────────
job = {
    "job_id"            : "test-local-001",
    "uid"               : "test-uid",
    "title"             : "Smart Attendance System using Face Recognition",
    "description"       : "A web-based attendance system using OpenCV and Flask.",
    "domain"            : "CSE / IT",
    "tech_stack"        : "Python, OpenCV, Flask, MySQL, React",
    "student_name"      : "Harsh Pareek",
    "batch_year"        : "2024-2025",
    "client"            : "LNCT Bhopal",
    "doc_color_hex"     : "#6C63FF",
    "notification_email": "",
    "fcm_token"         : None,
}

DUMMY_PARA = (
    "This chapter provides a comprehensive overview of the system. "
    "The proposed solution leverages modern technologies to address existing challenges. "
    "The implementation follows industry best practices and academic standards.\n\n"
    "The system architecture consists of multiple interconnected modules. "
    "Each module is responsible for a specific set of functionalities. "
    "The frontend provides an intuitive user interface for interaction.\n\n"
    "| Component | Technology | Purpose |\n"
    "| Frontend | React.js | User Interface |\n"
    "| Backend | Flask | API Server |\n"
    "| Database | MySQL | Data Storage |\n"
    "| ML Model | OpenCV | Face Detection |\n\n"
    "Testing was conducted across multiple environments and use cases. "
    "Unit tests verified individual component behavior. "
    "Performance benchmarks showed response times under 200 milliseconds.\n\n"
)

dummy_chapters = {name: DUMMY_PARA * 4 for name in CHAPTER_NAMES}

state = {
    "job"            : job,
    "chapter_plan"   : {},
    "context_summary": "",
    "chapters"       : dummy_chapters,
    "chapter_status" : {n: "done" for n in CHAPTER_NAMES},
    "retry_count"    : {},
    "quality_flags"  : {},
    "failed_chapters": [],
    "docx_bytes"     : b"",
    "viva_content"   : "Q1: What is face recognition?\nQ2: How does OpenCV detect faces?\nQ3: What is the accuracy of the system?",
    "summary_content": "This project implements a smart attendance system using face recognition technology.",
    "drive_url"      : "",
    "error"          : "",
}

# ── Step 1: Assembler ──────────────────────────────────────────────────────────
print("Step 1: Running assembler_node...")
state = assembler_node(state)
if not state["docx_bytes"]:
    print("ERROR: assembler_node produced empty docx_bytes")
    sys.exit(1)
print(f"  DOCX built: {len(state['docx_bytes'])} bytes")

# Also save locally for inspection
with open("test_output.docx", "wb") as f:
    f.write(state["docx_bytes"])
print("  Saved test_output.docx — open in Word to check formatting")

# ── Step 2: Delivery (real GCS upload + signed URL) ───────────────────────────
print("\nStep 2: Running delivery_node (uploading to Firebase Storage)...")

# Stub Firestore update so it doesn't need a real jobs/{id} document
_db = firestore.client()
try:
    _db.collection("jobs").document(job["job_id"]).set({
        "status": "processing", "title": job["title"],
        "uid": job["uid"],
    })
except Exception as e:
    print(f"  Warning: could not create test Firestore doc: {e}")

state = delivery_node(state)

if state.get("error"):
    print(f"\nERROR in delivery_node: {state['error']}")
    sys.exit(1)

print(f"\nSuccess!")
print(f"Download URL: {state['drive_url']}")
print("\nPaste the URL in a browser to download the ZIP.")

# Cleanup test Firestore doc
try:
    _db.collection("jobs").document(job["job_id"]).delete()
except Exception:
    pass
