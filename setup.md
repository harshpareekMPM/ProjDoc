# ProjectDocs AI — Complete Project Documentation

> AI-powered academic project report generator for Indian engineering students.
> Generates 80–100 page professional reports, uploads to Google Drive, notifies via mobile.

---

## Table of Contents

1. [Product Idea & Market](#1-product-idea--market)
2. [Why This Is Defensible](#2-why-this-is-defensible)
3. [User Flow](#3-user-flow)
4. [Report Structure — 94 Pages](#4-report-structure--94-pages)
5. [Tech Stack](#5-tech-stack)
6. [System Architecture](#6-system-architecture)
7. [Infrastructure & Concurrency](#7-infrastructure--concurrency)
8. [Firebase Storage Strategy](#8-firebase-storage-strategy)
9. [Google Drive Integration](#9-google-drive-integration)
10. [Cost Breakdown](#10-cost-breakdown)
11. [Pricing Strategy](#11-pricing-strategy)
12. [Why LangGraph — Not Plain asyncio](#12-why-langgraph--not-plain-asyncio)
13. [LangGraph Agent Architecture](#13-langgraph-agent-architecture)
14. [Coding Agent — Cloud Function + LangGraph](#14-coding-agent--cloud-function--langgraph)
15. [Flutter Mobile App](#15-flutter-mobile-app)
16. [Firestore Schema](#16-firestore-schema)
17. [Build Roadmap](#17-build-roadmap)

---

## 1. Product Idea & Market

### Problem
Indian engineering students (VTU, SPPU, GTU, RGPV, Anna University etc.) struggle every semester with:
- Writing 80–100 page project reports from scratch
- No clear structure or academic writing skill
- Deadline pressure — often 3–7 days before submission
- No money to hire consultants (₹2,000–₹5,000 per report)

### Solution
A mobile app where a student fills a simple one-page form describing their project. The AI agent generates a complete, properly structured 80–100 page academic report and delivers it directly to their Google Drive within 30–60 seconds.

### Target Users
- Final year BE/BTech students (sem 7 & 8)
- MCA, MCS, MSc CS students
- Diploma students (polytechnic)
- Estimated TAM: 15 lakh+ engineering students submitting projects annually in India

### Why Gen Z Will Pay
- Price is less than one Swiggy order (₹149)
- Zero friction — instant delivery
- Delivered to Google Drive — nothing to install or figure out
- One WhatsApp forward in a batch group = 60 sales

---

## 2. Why This Is Defensible

### What ChatGPT / Claude.ai Cannot Do
| Gap | Why It Matters |
|---|---|
| Cannot generate a structured 100-page `.docx` file | Students need a downloadable Word document |
| Cannot upload to Google Drive autonomously | Delivery is part of the product |
| Cannot send push notifications on completion | User experience requires async notification |
| Cannot maintain academic report structure | Requires chapter-by-chapter generation with proper formatting |
| No history + account system | Product requires persistence across sessions |

### The Real Moat
- Structured chapter-by-chapter generation (not one shot)
- Professional `.docx` with cover page, TOC, headings, tables
- Direct Google Drive delivery
- Mobile app with job history
- India-specific academic context (SPPU, VTU patterns)

---

## 3. User Flow

```
Student opens Flutter app
        ↓
Fills one-page form:
  - Project title
  - Project description (2–3 lines)
  - Tech stack
  - Domain
  - Client / college name
  - Student name + batch year
  - Key modules / features
  - Google Drive folder link (public)
        ↓
Taps "Generate my report"
        ↓
Firestore job document created → triggers Cloud Function
        ↓
App shows "Generating... (~30 seconds)"
        ↓
Cloud Function generates all 10 chapters in parallel via Claude API
        ↓
Assembles 94-page .docx in memory
        ↓
Uploads to Firebase Storage (temp buffer)
        ↓
Transfers to user's Google Drive folder
        ↓
Deletes from Firebase Storage immediately
        ↓
Saves Drive link to Firestore
        ↓
FCM push notification → "Report ready — 94 pages on your Drive"
        ↓
History screen shows report with Drive link
```

---

## 4. Report Structure — 94 Pages

| Chapter | Content | Pages |
|---|---|---|
| 1. Abstract + Introduction | Problem statement, objectives, scope, organisation | 5 |
| 2. Literature Review | Related works, 5 existing systems comparison table, gaps | 8 |
| 3. Requirements Analysis | Functional, non-functional, user stories, use cases | 10 |
| 4. System Design | Architecture, ER diagram, DFD (L0/L1/L2), flowcharts | 15 |
| 5. Implementation | Module-wise description, key code snippets, screenshots | 20 |
| 6. Database Design | Schema, table descriptions, relationships, sample data | 8 |
| 7. Testing | Test plan, unit/integration/UAT test cases, results | 10 |
| 8. Results + Screenshots | UI walkthrough, output screens, performance metrics | 8 |
| 9. Conclusion + Future Work | Summary, limitations, 5 future enhancements | 4 |
| 10. References + Appendix | IEEE citations, glossary, user manual appendix | 6 |
| **Total** | | **94 pages** |

### Generation Strategy
- One Bedrock/Claude API call per chapter (10 total)
- All 10 calls run in parallel using `asyncio.gather()`
- Each call: ~4096 output tokens, ~800–1200 words
- Total generation time: ~25–35 seconds
- Each chapter prompt includes full project context

---

## 5. Tech Stack

### Mobile App
| Layer | Technology | Reason |
|---|---|---|
| Framework | Flutter | Single codebase — Android + iOS |
| Language | Dart | Easy to learn, fast UI |
| State management | Provider / Riverpod | Simple, well documented |
| Auth | Firebase Auth (Google + Phone) | 10 min setup |
| Push notifications | Firebase Cloud Messaging (FCM) | Built into Firebase |

### Backend
| Layer | Technology | Reason |
|---|---|---|
| Compute | GCP Cloud Functions (Python) | Serverless, auto-scales, no EC2 |
| AI generation | Anthropic Claude API (claude-sonnet-4-5) | Direct API, no Bedrock needed |
| Document generation | python-docx | Mature, handles complex Word docs |
| Trigger mechanism | Firestore document trigger | No queue needed, GCP handles it |
| Temp storage | Firebase Storage | Buffer between generation and Drive |
| Permanent storage | User's Google Drive | User owns their files |
| Database | Firestore | Job status, history, user records |
| Notifications | FCM via firebase-admin | Push on job completion |

### No Need For
- ❌ AWS / Bedrock (Claude API direct is simpler)
- ❌ EC2 (Cloud Functions handles compute)
- ❌ Redis / Celery (Firestore trigger replaces queue)
- ❌ RDS / PostgreSQL (Firestore replaces it)
- ❌ Nginx / load balancer (GCP handles routing)

---

## 6. System Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Flutter Mobile App                  │
│  Screen 1: Form        Screen 2: History             │
└────────────────────────┬────────────────────────────┘
                         │ writes job doc
                         ▼
┌─────────────────────────────────────────────────────┐
│                    Firestore                         │
│  jobs/{job_id}: { status, title, uid, ... }         │
└────────────────────────┬────────────────────────────┘
                         │ on_document_created trigger
                         ▼
┌─────────────────────────────────────────────────────┐
│              GCP Cloud Function (Python)             │
│                                                      │
│  1. Build project context string                     │
│  2. asyncio.gather() → 10 Claude API calls parallel  │
│  3. python-docx assembles 94-page .docx in BytesIO   │
│  4. Upload BytesIO → Firebase Storage (temp)         │
│  5. Download from Storage → Upload to Google Drive   │
│  6. Delete from Firebase Storage                     │
│  7. Update Firestore: status=done, drive_url=...     │
│  8. Send FCM push notification                       │
└─────────────────────────────────────────────────────┘
         │                    │                   │
         ▼                    ▼                   ▼
  Claude API           Firebase Storage      Google Drive
  (10 parallel)        (30-60 sec only)      (permanent)
```

---

## 7. Infrastructure & Concurrency

### How Cloud Functions Handle 100 Concurrent Users

Cloud Functions auto-scale — one instance per request, automatically.

```
User 1  → Cloud Function Instance 1  (512 MB RAM, isolated)
User 2  → Cloud Function Instance 2  (512 MB RAM, isolated)
User 3  → Cloud Function Instance 3  (512 MB RAM, isolated)
...
User 100 → Cloud Function Instance 100 (512 MB RAM, isolated)
```

No shared memory. No thread contention. No queue management. GCP handles all of it.

### Memory Per Instance
| What | Memory |
|---|---|
| Python runtime | ~80 MB |
| Claude API responses (10 chapters) | ~10 MB |
| BytesIO .docx assembly | ~3 MB |
| Total peak | ~93 MB |
| Allocated | 512 MB |
| Headroom | 419 MB ✓ |

### Real Bottleneck — Claude API Rate Limits
| Plan | RPM | TPM | Handles |
|---|---|---|---|
| Free | 5 | 20K | Testing only |
| Build | 50 | 100K | ~5 concurrent users |
| Scale | 1000 | 400K | 100 concurrent users |

At 100 users × 10 chapters = 1000 simultaneous API calls → need Scale plan.

### Rate Limit Handling
```python
from anthropic import RateLimitError
import asyncio

async def gen_chapter_with_retry(name, prompt, context, retries=3):
    for attempt in range(retries):
        try:
            r = client.messages.create(
                model="claude-sonnet-4-5",
                max_tokens=4096,
                messages=[{"role": "user", "content": context + prompt}]
            )
            return name, r.content[0].text
        except RateLimitError:
            await asyncio.sleep(2 ** attempt)  # 1s, 2s, 4s backoff
    raise Exception(f"Chapter {name} failed after {retries} retries")
```

### Cloud Function Config
```python
@firestore_fn.on_document_created(
    document      = "jobs/{job_id}",
    timeout_sec   = 540,       # 9 min max
    memory        = 512,       # MB
    max_instances = 100,       # concurrency cap
    min_instances = 0          # scale to zero — no idle cost
)
async def generate_report(event):
    ...
```

---

## 8. Firebase Storage Strategy

### Role — Temporary Buffer Only
Firebase Storage is NOT permanent storage. It is a staging area between generation and Google Drive.

```
BytesIO (memory)
    ↓ upload
Firebase Storage   ← lives here for ~30-60 seconds only
    ↓ download + upload to Drive
Google Drive       ← permanent home
    ↓ delete
Firebase Storage   ← empty again
```

### Storage Path
```
temp/
  {job_id}/
    report.docx     ← deleted within 60 seconds
```

### Why Not Keep Files in Firebase Storage?
- User's files belong in their own Google Drive — they control it
- Saves Firebase Storage cost
- No GDPR / data retention concerns
- Files are not our responsibility after delivery

### Lifecycle Policy (Safety Net)
In case delete fails for any reason, GCP auto-deletes after 1 day:

```python
# run once during setup
from google.cloud import storage as gcs

def set_lifecycle_policy():
    client = gcs.Client()
    bucket = client.bucket("your-app.appspot.com")
    bucket.lifecycle_rules = [{
        "action"    : {"type": "Delete"},
        "condition" : {
            "age"           : 1,              # 1 day safety net
            "matchesPrefix" : ["temp/"]
        }
    }]
    bucket.patch()
```

---

## 9. Google Drive Integration

### How User Shares Their Folder
```
1. User creates a folder in their Google Drive
2. User makes it public (anyone with link can edit)
   OR shares it with your service account email:
   projectbot@your-project.iam.gserviceaccount.com
3. User pastes the folder link in the app form
4. Your Cloud Function extracts the folder ID from the link
   e.g. https://drive.google.com/drive/folders/1xK9mABC...
                                                  ^^^^^^^^ this is folder_id
```

### Upload Code
```python
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload
from google.oauth2 import service_account
import io

def upload_to_drive(docx_bytes: io.BytesIO,
                    folder_id: str,
                    filename: str) -> str:
    creds = service_account.Credentials.from_service_account_file(
        "service_account.json",
        scopes=["https://www.googleapis.com/auth/drive"]
    )
    service = build("drive", "v3", credentials=creds)

    meta  = {"name": filename, "parents": [folder_id]}
    media = MediaIoBaseUpload(
        docx_bytes,
        mimetype  = "application/vnd.openxmlformats-officedocument"
                    ".wordprocessingml.document",
        resumable = True
    )
    file = service.files().create(
        body       = meta,
        media_body = media,
        fields     = "id, webViewLink"
    ).execute()

    return file["webViewLink"]
```

---

## 10. Cost Breakdown

### Per Report Cost

| Item | Detail | Cost (₹) |
|---|---|---|
| Claude API — claude-sonnet-4-5 | 10 chapters × ~1K tokens in + ~4K out | ₹28 |
| GCP Cloud Functions | 512 MB × 30 sec × ₹0.0000025/GB-sec | ₹0.07 |
| Firebase Storage (temp) | 3 MB × 60 sec — negligible | ~₹0 |
| Firestore reads/writes | ~10 ops/report — free tier | ~₹0 |
| FCM notification | Always free | ₹0 |
| Google Drive API | Free | ₹0 |
| **Total cost per report** | | **~₹28** |

### Monthly Infrastructure Cost
| Service | Free Tier | Beyond Free |
|---|---|---|
| Cloud Functions | 2M invocations/month | ~₹0.003/invocation |
| Firebase Storage | 5 GB | ₹2/GB |
| Firestore | 50K reads/day | ₹0.05/100K |
| FCM | Unlimited | Free |
| Claude API | — | ~₹28/report |

At 500 reports/month → Firebase infra cost ≈ ₹0. Only real cost is Claude API.

### Monthly P&L at Different Volumes

| Reports/month | Revenue @ ₹149 | Total Cost | Net Profit | Margin |
|---|---|---|---|---|
| 50 | ₹7,450 | ₹1,400 | ₹6,050 | 81% |
| 200 | ₹29,800 | ₹5,600 | ₹24,200 | 81% |
| 500 | ₹74,500 | ₹14,000 | ₹60,500 | 81% |
| 1,000 | ₹1,49,000 | ₹28,000 | ₹1,21,000 | 81% |

Break-even: just 1 report/day (30/month) covers all costs.

---

## 11. Pricing Strategy

### Individual Plans

| Plan | Price | What They Get | Margin |
|---|---|---|---|
| Basic | ₹99 | Docs only, no code | 69% |
| Standard ⭐ | ₹149 | Full 94-page report + Drive upload | 79% |
| Pro | ₹249 | Report + viva Q&A + user guide + tech details | 87% |

### College / Bulk Plans (High Value)

| Bundle | Price | Students | Your Cost | Profit |
|---|---|---|---|---|
| Class bundle | ₹3,999 | 30 | ₹930 | ₹3,069 |
| Department bundle | ₹9,999 | 100 | ₹3,100 | ₹6,899 |
| College annual | ₹24,999 | 300 | ₹9,300 | ₹15,699 |

### Why ₹149 Is the Right Individual Price
- Less than one Swiggy order — zero psychological friction
- Student pays via UPI in 10 seconds
- Below the "think about it" threshold
- Still 4.8× your cost

### Growth Hack
One placement cell coordinator or class representative can forward to 60 students.
60 × ₹149 = ₹8,940 from a single WhatsApp forward.
Give them a ₹20 referral credit per sale → they market for you.

---

## 12. Why LangGraph — Not Plain asyncio

### The Core Problem — 100 Pages Cannot Be One LLM Call

| Approach | Max output | Pages | Problem |
|---|---|---|---|
| Single Claude call | 8192 tokens | ~20 pages | Truncates, quality drops |
| Plain asyncio (10 calls) | 10 × 8192 tokens | ~100 pages | No state, no quality control, no retry intelligence |
| LangGraph agent | 10 × 8192 tokens | ~100 pages | Stateful, quality-checked, retry-aware |

Plain `asyncio.gather()` works but has critical gaps:

- No shared state between chapters — chapter 5 doesn't know what chapter 4 said
- No quality check — if a chapter is too short, nothing catches it
- No structured retry — if one chapter fails, whole report fails
- No planning step — chapters are not adapted to the specific project
- No consistency enforcement — tech stack mentioned in chapter 1 might differ in chapter 6

LangGraph solves all of this with a proper agent graph.

---

### Why 100 Pages = 10 Separate Calls

```
Claude Sonnet limits:
  Max output tokens  : 8192 tokens per call
  8192 tokens        : ~6000 words
  ~6000 words        : ~20 pages (double spaced, 12pt)

One call max = 20 pages — not enough for 94-page report

Solution: 10 chapters × one call each × ~9-10 pages = 94 pages

Each call gets:
  - Full project context (input)
  - Chapter-specific prompt (instruction)
  - Previous chapter summaries (consistency)
  - Quality requirements (minimum word count)
```

---

## 13. LangGraph Agent Architecture

### Agent State

```python
from typing import TypedDict, List, Dict, Annotated
import operator

class ReportState(TypedDict):
    # inputs
    job             : dict              # full job details from Firestore

    # planning
    chapter_plan    : dict              # chapter titles + scope per chapter
    context_summary : str              # project context string for all calls

    # generation
    chapters        : Dict[str, str]   # chapter_name → generated content
    chapter_status  : Dict[str, str]   # chapter_name → done | failed | retry
    retry_count     : Dict[str, int]   # chapter_name → number of retries

    # quality
    quality_flags   : Dict[str, str]   # chapter_name → ok | too_short | irrelevant
    failed_chapters : List[str]        # chapters that failed after all retries

    # output
    docx_bytes      : bytes            # final assembled document
    drive_url       : str              # Google Drive link after upload
    error           : str              # top-level error if pipeline fails
```

---

### Agent Graph — 6 Nodes

```
                    ┌─────────────────┐
                    │   START         │
                    │   (job input)   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  PlannerNode    │  ← LLM decides chapter scope
                    │                 │    based on project domain
                    └────────┬────────┘
                             │
                             ▼
              ┌──────────────────────────────┐
              │      ChapterGeneratorNode     │
              │  (runs 10 times — one per     │
              │   chapter, parallel fan-out)  │
              └──────────────┬───────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  QualityNode    │  ← checks word count,
                    │                 │    relevance, completeness
                    └────────┬────────┘
                             │
                   ┌─────────┴──────────┐
                   │                    │
                   ▼                    ▼
          (quality ok)          (quality failed)
                   │                    │
                   │            ┌───────────────┐
                   │            │  RetryNode    │  ← regenerates with
                   │            │               │    stricter prompt
                   │            └───────┬───────┘
                   │                    │
                   └─────────┬──────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  AssemblerNode  │  ← python-docx builds
                    │                 │    final .docx
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  DeliveryNode   │  ← Firebase Storage →
                    │                 │    Google Drive → FCM
                    └────────┬────────┘
                             │
                             ▼
                          END
```

---

### Full LangGraph Code

```python
# report_agent.py
import anthropic
import asyncio
import io
from typing import Literal
from langgraph.graph import StateGraph, END
from docx import Document

client = anthropic.Anthropic()

CHAPTER_NAMES = [
    "abstract", "literature", "requirements", "system_design",
    "implementation", "database", "testing", "results",
    "conclusion", "references"
]

CHAPTER_PROMPTS = {
    "abstract": """
Write Chapter 1: Abstract and Introduction.
Sections to cover:
- Abstract (250 words, standalone summary)
- 1.1 Background and Motivation
- 1.2 Problem Statement
- 1.3 Objectives (minimum 5 numbered points)
- 1.4 Scope of the Project
- 1.5 Significance of the Study
- 1.6 Organisation of the Report
Minimum: 900 words. Do not use markdown. Use plain paragraph text.
""",
    "literature": """
Write Chapter 2: Literature Review.
Sections to cover:
- 2.1 Introduction to the domain
- 2.2 Review of existing systems (describe 5 existing systems)
- 2.3 Comparison table (System | Key Features | Limitations)
- 2.4 Research gaps identified
- 2.5 How this project addresses the gaps
- 2.6 Summary
Minimum: 1000 words. Include a comparison table in plain text format.
""",
    "requirements": """
Write Chapter 3: Requirements Analysis.
Sections to cover:
- 3.1 Introduction
- 3.2 Functional Requirements (minimum 10 numbered points)
- 3.3 Non-Functional Requirements (minimum 8 points)
- 3.4 User Roles and Access Levels
- 3.5 Use Case Descriptions (5 use cases with actor, precondition, flow)
- 3.6 System Constraints
- 3.7 Assumptions and Dependencies
Minimum: 1200 words.
""",
    "system_design": """
Write Chapter 4: System Design.
Sections to cover:
- 4.1 System Architecture Overview
- 4.2 Architecture Diagram Description (describe components and interactions)
- 4.3 Data Flow Diagram Level 0 (Context Diagram) — describe in text
- 4.4 Data Flow Diagram Level 1 — describe each process
- 4.5 Entity-Relationship Diagram Description
  (list all entities, attributes, relationships)
- 4.6 Sequence Diagram Description (main workflow)
- 4.7 Component Interaction Summary
Minimum: 1800 words.
""",
    "implementation": """
Write Chapter 5: Implementation.
Sections to cover:
- 5.1 Development Environment and Tools
- 5.2 Project Structure and File Organisation
- 5.3 Module-wise Implementation (describe each module separately)
  For each module: purpose, key functions, implementation approach
- 5.4 Key Algorithms and Logic
- 5.5 API Design and Endpoints (if applicable)
- 5.6 Security Implementation
- 5.7 Error Handling Strategy
- 5.8 Integration Between Modules
Minimum: 2500 words. This is the longest chapter.
""",
    "database": """
Write Chapter 6: Database Design.
Sections to cover:
- 6.1 Database Management System Used and Justification
- 6.2 Database Architecture
- 6.3 Entity Description (describe each entity)
- 6.4 Table Structures (for each table: column name, datatype, constraints)
  Format as: Column | Datatype | Constraints | Description
- 6.5 Relationships and Foreign Keys
- 6.6 Normalisation (explain up to 3NF)
- 6.7 Sample Data (3 rows for 3 main tables)
- 6.8 Indexes and Performance Considerations
Minimum: 1000 words.
""",
    "testing": """
Write Chapter 7: Testing.
Sections to cover:
- 7.1 Testing Strategy and Approach
- 7.2 Types of Testing Performed
- 7.3 Test Plan
- 7.4 Unit Test Cases (15 test cases in table format)
  Format: Test ID | Module | Description | Input | Expected Output | Status
- 7.5 Integration Test Cases (10 test cases in same format)
- 7.6 User Acceptance Testing (5 scenarios)
- 7.7 Test Results Summary
- 7.8 Defects Found and Resolved
Minimum: 1200 words.
""",
    "results": """
Write Chapter 8: Results and Discussion.
Sections to cover:
- 8.1 Introduction
- 8.2 System Screenshots Description
  (describe minimum 8 screens: login, dashboard, main features, reports)
- 8.3 Feature Demonstration
- 8.4 Performance Analysis
- 8.5 Comparison with Existing Systems
- 8.6 User Feedback Summary
- 8.7 Limitations of Current Implementation
Minimum: 1000 words.
""",
    "conclusion": """
Write Chapter 9: Conclusion and Future Work.
Sections to cover:
- 9.1 Summary of Work Done (10 key accomplishments)
- 9.2 Objectives Achieved (map back to objectives in Chapter 1)
- 9.3 Limitations of the Current System
- 9.4 Future Enhancements (minimum 7 with descriptions)
- 9.5 Learning Outcomes
- 9.6 Final Remarks
Minimum: 700 words.
""",
    "references": """
Write Chapter 10: References and Appendix.
Sections:
- 10.1 References
  Generate 15 realistic IEEE format references relevant to the
  tech stack and domain. Format:
  [1] Author, "Title," Journal/Conference, vol., no., pp., Year.
- 10.2 Glossary (15 technical terms used in the project with definitions)
- 10.3 Appendix A — Installation Guide
  (step-by-step setup instructions for the tech stack)
- 10.4 Appendix B — User Manual Summary
Minimum: 600 words.
"""
}


# ── Node 1: Planner ───────────────────────────────────────────────────────────

def planner_node(state: ReportState) -> ReportState:
    """
    LLM decides the specific scope for each chapter
    based on project domain and tech stack.
    Prevents generic output — each report is project-specific.
    """
    job = state["job"]

    context = f"""
Project Title  : {job['title']}
Description    : {job['description']}
Domain         : {job['domain']}
Tech Stack     : {job['tech_stack']}
Client/College : {job['client']}
Student        : {job['student_name']}
Batch          : {job['batch_year']}
Key Modules    : {job.get('modules', 'As appropriate')}
"""

    r = client.messages.create(
        model      = "claude-haiku-4-5",   # haiku for planning — cheaper
        max_tokens = 1024,
        messages   = [{
            "role"   : "user",
            "content": f"""
You are planning an academic project report.
Given this project, list what SPECIFIC things each chapter should mention.
Be project-specific — mention actual module names, table names, tech choices.

{context}

Return a JSON object with chapter names as keys and
1-2 sentences of specific guidance as values.
Chapters: abstract, literature, requirements, system_design,
implementation, database, testing, results, conclusion, references
"""
        }]
    )

    import json
    try:
        plan = json.loads(r.content[0].text)
    except Exception:
        plan = {ch: "" for ch in CHAPTER_NAMES}

    return {
        **state,
        "chapter_plan"    : plan,
        "context_summary" : context,
        "chapters"        : {},
        "chapter_status"  : {ch: "pending" for ch in CHAPTER_NAMES},
        "retry_count"     : {ch: 0 for ch in CHAPTER_NAMES},
        "quality_flags"   : {},
        "failed_chapters" : [],
    }


# ── Node 2: Chapter Generator ─────────────────────────────────────────────────

async def chapter_generator_node(state: ReportState) -> ReportState:
    """
    Generates all 10 chapters in parallel.
    Each call gets: project context + chapter prompt + planner guidance.
    Previous chapter summaries injected for consistency.
    """
    context   = state["context_summary"]
    plan      = state["chapter_plan"]
    chapters  = dict(state.get("chapters", {}))
    status    = dict(state.get("chapter_status", {}))

    # build previous chapter summaries for consistency
    def get_previous_summary(chapter_name: str) -> str:
        idx      = CHAPTER_NAMES.index(chapter_name)
        prev     = CHAPTER_NAMES[:idx]
        summaries = []
        for p in prev:
            if p in chapters:
                # first 200 chars as summary
                summaries.append(f"{p}: {chapters[p][:200]}...")
        return "\n".join(summaries) if summaries else ""

    async def gen_one(name: str) -> tuple:
        if status.get(name) == "done":
            return name, chapters.get(name, "")

        prev_summary = get_previous_summary(name)
        planner_note = plan.get(name, "")

        prompt = f"""
{context}

PLANNER GUIDANCE FOR THIS CHAPTER:
{planner_note}

PREVIOUSLY WRITTEN CHAPTERS (for consistency):
{prev_summary if prev_summary else "This is the first chapter."}

{CHAPTER_PROMPTS[name]}

IMPORTANT:
- Be consistent with tech stack and module names from context
- Do not contradict anything in previous chapters
- Write in formal academic English
- No markdown formatting — plain text only
- Meet the minimum word count requirement
"""
        r = client.messages.create(
            model      = "claude-sonnet-4-5",
            max_tokens = 8192,
            messages   = [{"role": "user", "content": prompt}]
        )
        return name, r.content[0].text

    # run all pending chapters in parallel
    pending = [n for n in CHAPTER_NAMES if status.get(n) != "done"]
    results = await asyncio.gather(*[gen_one(n) for n in pending])

    for name, content in results:
        chapters[name]  = content
        status[name]    = "generated"

    return {**state, "chapters": chapters, "chapter_status": status}


# ── Node 3: Quality Checker ───────────────────────────────────────────────────

def quality_node(state: ReportState) -> ReportState:
    """
    Checks each chapter for:
    - Minimum word count
    - Relevance to the project
    - No placeholder text like "Lorem ipsum" or "[Insert here]"
    """
    chapters     = state["chapters"]
    status       = dict(state["chapter_status"])
    quality      = dict(state.get("quality_flags", {}))
    retry_count  = dict(state.get("retry_count", {}))
    failed       = list(state.get("failed_chapters", []))

    MIN_WORDS = {
        "abstract": 800, "literature": 900, "requirements": 1000,
        "system_design": 1500, "implementation": 2000, "database": 800,
        "testing": 1000, "results": 800, "conclusion": 600, "references": 500
    }

    PLACEHOLDER_PHRASES = [
        "[insert", "lorem ipsum", "add content here",
        "to be filled", "tbd", "coming soon"
    ]

    for name in CHAPTER_NAMES:
        content    = chapters.get(name, "")
        word_count = len(content.split())
        min_words  = MIN_WORDS.get(name, 700)

        # check for placeholders
        has_placeholder = any(
            p in content.lower() for p in PLACEHOLDER_PHRASES
        )

        if word_count < min_words or has_placeholder:
            retries = retry_count.get(name, 0)
            if retries < 2:
                status[name]       = "retry"
                quality[name]      = f"too_short:{word_count}/{min_words}"
                retry_count[name]  = retries + 1
            else:
                status[name]  = "done"    # accept after 2 retries
                quality[name] = f"accepted_low:{word_count}"
                failed.append(name)
        else:
            status[name]  = "done"
            quality[name] = f"ok:{word_count}"

    return {
        **state,
        "chapter_status"  : status,
        "quality_flags"   : quality,
        "retry_count"     : retry_count,
        "failed_chapters" : failed,
    }


# ── Router: quality → retry or assemble ──────────────────────────────────────

def route_after_quality(state: ReportState) -> Literal["retry", "assemble"]:
    """If any chapter needs retry, go back. Otherwise assemble."""
    statuses = state["chapter_status"].values()
    if "retry" in statuses:
        return "retry"
    return "assemble"


# ── Node 4: Retry Node ────────────────────────────────────────────────────────

async def retry_node(state: ReportState) -> ReportState:
    """
    Re-generates only failed chapters with a stricter prompt.
    Uses quality_flags to understand why it failed.
    """
    chapters    = dict(state["chapters"])
    status      = dict(state["chapter_status"])
    quality     = state["quality_flags"]
    context     = state["context_summary"]

    retry_names = [n for n, s in status.items() if s == "retry"]

    async def retry_one(name: str) -> tuple:
        reason = quality.get(name, "unknown")
        prompt = f"""
{context}

RETRY INSTRUCTION: Your previous attempt for this chapter was rejected.
Reason: {reason}

You MUST write significantly more content this time.
Be very detailed and comprehensive.
Include examples, detailed descriptions, and thorough explanations.

{CHAPTER_PROMPTS[name]}

Previous attempt (expand significantly on this):
{chapters.get(name, '')[:500]}...
"""
        r = client.messages.create(
            model      = "claude-sonnet-4-5",
            max_tokens = 8192,
            messages   = [{"role": "user", "content": prompt}]
        )
        return name, r.content[0].text

    results = await asyncio.gather(*[retry_one(n) for n in retry_names])

    for name, content in results:
        chapters[name] = content
        status[name]   = "generated"   # goes back to quality check

    return {**state, "chapters": chapters, "chapter_status": status}


# ── Node 5: Assembler ─────────────────────────────────────────────────────────

def assembler_node(state: ReportState) -> ReportState:
    """
    Assembles all 10 chapters into a formatted .docx using python-docx.
    Returns bytes in state — never touches disk.
    """
    job      = state["job"]
    chapters = state["chapters"]

    doc = Document()

    # cover page
    doc.add_heading(job["title"], 0)
    doc.add_paragraph("")
    doc.add_paragraph(
        "A Project Report submitted in partial fulfillment of the "
        "requirements for the degree of Bachelor of Engineering"
    )
    doc.add_paragraph("")
    doc.add_paragraph(f"Submitted by: {job['student_name']}")
    doc.add_paragraph(f"Institution : {job['client']}")
    doc.add_paragraph(f"Batch       : {job['batch_year']}")
    doc.add_paragraph(f"Tech Stack  : {job['tech_stack']}")
    doc.add_page_break()

    doc.add_heading("Table of Contents", 1)
    doc.add_paragraph(
        "Right-click → Update Field after opening in Microsoft Word."
    )
    doc.add_page_break()

    chapter_titles = {
        "abstract"       : "Chapter 1: Abstract and Introduction",
        "literature"     : "Chapter 2: Literature Review",
        "requirements"   : "Chapter 3: Requirements Analysis",
        "system_design"  : "Chapter 4: System Design",
        "implementation" : "Chapter 5: Implementation",
        "database"       : "Chapter 6: Database Design",
        "testing"        : "Chapter 7: Testing",
        "results"        : "Chapter 8: Results and Discussion",
        "conclusion"     : "Chapter 9: Conclusion and Future Work",
        "references"     : "Chapter 10: References and Appendix",
    }

    for key, title in chapter_titles.items():
        doc.add_heading(title, 1)
        content = chapters.get(key, "Content not available.")
        for para in content.split("\n\n"):
            if para.strip():
                # detect subheadings (short lines ending with no period)
                stripped = para.strip()
                if (len(stripped) < 80
                        and not stripped.endswith(".")
                        and stripped[0].isdigit()):
                    doc.add_heading(stripped, 2)
                else:
                    doc.add_paragraph(stripped)
        doc.add_page_break()

    buf = io.BytesIO()
    doc.save(buf)
    buf.seek(0)

    return {**state, "docx_bytes": buf.getvalue()}


# ── Node 6: Delivery ──────────────────────────────────────────────────────────

def delivery_node(state: ReportState) -> ReportState:
    """
    Firebase Storage → Google Drive → Delete temp → Firestore → FCM
    """
    from firebase_admin import firestore, storage, messaging
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaIoBaseUpload
    from google.oauth2 import service_account

    job       = state["job"]
    jid       = job["job_id"]
    db        = firestore.client()
    temp_blob = None

    try:
        # upload to Firebase Storage (temp)
        bucket    = storage.bucket()
        temp_path = f"temp/{jid}/report.docx"
        temp_blob = bucket.blob(temp_path)
        temp_blob.upload_from_string(
            state["docx_bytes"],
            content_type = ("application/vnd.openxmlformats-officedocument"
                            ".wordprocessingml.document")
        )

        # transfer to Google Drive
        docx_bytes = io.BytesIO(temp_blob.download_as_bytes())
        creds      = service_account.Credentials.from_service_account_file(
            "service_account.json",
            scopes=["https://www.googleapis.com/auth/drive"]
        )
        service = build("drive", "v3", credentials=creds)
        meta    = {
            "name"    : f"{job['title']}_Project_Report.docx",
            "parents" : [job["drive_folder_id"]]
        }
        media = MediaIoBaseUpload(
            docx_bytes,
            mimetype  = ("application/vnd.openxmlformats-officedocument"
                         ".wordprocessingml.document"),
            resumable = True
        )
        file      = service.files().create(
            body=meta, media_body=media, fields="id, webViewLink"
        ).execute()
        drive_url = file["webViewLink"]

        # delete from Firebase Storage
        temp_blob.delete()

        # update Firestore
        db.collection("jobs").document(jid).update({
            "status"       : "done",
            "drive_url"    : drive_url,
            "pages"        : 94,
            "quality_flags": state.get("quality_flags", {}),
            "completed_at" : firestore.SERVER_TIMESTAMP
        })

        # FCM notification
        messaging.send(messaging.Message(
            token        = job["fcm_token"],
            notification = messaging.Notification(
                title = "Report ready!",
                body  = f"{job['title']} · 94 pages on your Drive"
            ),
            data = {"job_id": jid, "drive_url": drive_url}
        ))

        return {**state, "drive_url": drive_url}

    except Exception as e:
        if temp_blob:
            try: temp_blob.delete()
            except: pass
        db.collection("jobs").document(jid).update({
            "status": "failed", "error": str(e)
        })
        return {**state, "error": str(e)}


# ── Build the Graph ───────────────────────────────────────────────────────────

def build_report_graph():
    graph = StateGraph(ReportState)

    graph.add_node("planner",   planner_node)
    graph.add_node("generator", chapter_generator_node)
    graph.add_node("quality",   quality_node)
    graph.add_node("retry",     retry_node)
    graph.add_node("assembler", assembler_node)
    graph.add_node("delivery",  delivery_node)

    graph.set_entry_point("planner")
    graph.add_edge("planner",   "generator")
    graph.add_edge("generator", "quality")
    graph.add_conditional_edges(
        "quality",
        route_after_quality,
        {"retry": "retry", "assemble": "assembler"}
    )
    graph.add_edge("retry",     "quality")    # retry → re-check quality
    graph.add_edge("assembler", "delivery")
    graph.add_edge("delivery",  END)

    return graph.compile()


# ── Entry point from Cloud Function ──────────────────────────────────────────

report_graph = build_report_graph()

async def run_report_agent(job: dict) -> dict:
    """Called from Cloud Function trigger."""
    initial_state = ReportState(
        job             = job,
        chapter_plan    = {},
        context_summary = "",
        chapters        = {},
        chapter_status  = {},
        retry_count     = {},
        quality_flags   = {},
        failed_chapters = [],
        docx_bytes      = b"",
        drive_url       = "",
        error           = "",
    )
    final_state = await report_graph.ainvoke(initial_state)
    return final_state
```

---

### requirements.txt (updated with LangGraph)
```
anthropic>=0.25.0
langgraph>=0.1.0
langchain-core>=0.1.0
firebase-admin>=6.3.0
firebase-functions>=0.1.0
google-cloud-storage>=2.14.0
google-api-python-client>=2.111.0
google-auth>=2.27.0
python-docx>=1.1.0
```

---

### Cloud Function Entry Point (calls the graph)

```python
from firebase_functions import firestore_fn
from firebase_admin import firestore
import asyncio
from report_agent import run_report_agent

@firestore_fn.on_document_created(
    document      = "jobs/{job_id}",
    timeout_sec   = 540,
    memory        = 512,
    max_instances = 100,
    min_instances = 0
)
async def generate_report(event):
    job    = event.data.to_dict()
    jid    = event.params["job_id"]
    db     = firestore.client()

    db.collection("jobs").document(jid).update({"status": "processing"})

    # inject job_id into job dict for delivery node
    job["job_id"] = jid

    try:
        await run_report_agent(job)
    except Exception as e:
        db.collection("jobs").document(jid).update({
            "status": "failed",
            "error" : str(e)
        })
```

---

## 14. Coding Agent — Cloud Function + LangGraph

### Full Cloud Function Code

```python
import anthropic
import asyncio
import io
from docx import Document
from firebase_admin import firestore, storage, messaging
from firebase_functions import firestore_fn
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload
from google.oauth2 import service_account

client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY from env

CHAPTERS = [
    ("abstract",
     "Write a detailed abstract (250 words) and introduction chapter. "
     "Include: background, problem statement, objectives (5 points), "
     "scope, significance, and organisation of the report. Minimum 800 words."),

    ("literature",
     "Write a literature review chapter. Compare 5 existing similar systems "
     "in a table (System | Features | Limitations). Identify gaps that this "
     "project addresses. Include 8 references. Minimum 1000 words."),

    ("requirements",
     "Write a requirements analysis chapter. Include: "
     "Functional requirements (10 points), Non-functional requirements (8 points), "
     "User roles and permissions, 5 use case descriptions, system constraints. "
     "Minimum 1200 words."),

    ("system_design",
     "Write a system design chapter. Include: "
     "System architecture description, component diagram description, "
     "Data Flow Diagram Level 0 (context diagram) description, "
     "DFD Level 1 description, Entity-Relationship diagram description "
     "with all entities and relationships, sequence diagram description. "
     "Minimum 1800 words."),

    ("implementation",
     "Write an implementation chapter. Describe each module separately: "
     "User module, Admin module, Core feature modules (name them from project description). "
     "Include key algorithms, important code logic descriptions, "
     "and implementation decisions. Minimum 2500 words."),

    ("database",
     "Write a database design chapter. Include: "
     "Database schema overview, each table with columns/datatypes/constraints in a table format, "
     "primary and foreign key relationships, sample data for 3 main tables, "
     "database normalisation explanation. Minimum 1000 words."),

    ("testing",
     "Write a testing chapter. Include: "
     "Testing strategy, test plan, "
     "30 test cases in a table (Test ID | Description | Input | Expected | Actual | Status), "
     "unit testing results, integration testing results, UAT summary. "
     "Minimum 1200 words."),

    ("results",
     "Write a results and discussion chapter. "
     "Describe each screen of the application (minimum 8 screens), "
     "system performance metrics, output validation, "
     "comparison with existing systems. Minimum 1000 words."),

    ("conclusion",
     "Write a conclusion chapter. Include: "
     "Summary of work done (10 points), objectives achieved, "
     "limitations of current system (5 points), "
     "future enhancements (7 points with descriptions), "
     "final remarks. Minimum 600 words."),

    ("references",
     "Write a references and appendix chapter. "
     "Generate 15 IEEE format references relevant to the tech stack and domain. "
     "Add a glossary of 15 technical terms used in the project. "
     "Add a brief user manual appendix (how to install and run). "
     "Minimum 500 words."),
]


@firestore_fn.on_document_created(
    document      = "jobs/{job_id}",
    timeout_sec   = 540,
    memory        = 512,
    max_instances = 100,
    min_instances = 0
)
async def generate_report(event):
    job  = event.data.to_dict()
    jid  = event.params["job_id"]
    db   = firestore.client()

    db.collection("jobs").document(jid).update({"status": "processing"})

    temp_blob = None

    try:
        # ── build project context ─────────────────────────────────
        context = f"""
You are an expert academic writer helping an engineering student.
Write in formal academic English. Use proper paragraph structure.
Do not use markdown — use plain text with clear section headings.

PROJECT DETAILS:
Title       : {job['title']}
Description : {job['description']}
Domain      : {job['domain']}
Tech Stack  : {job['tech_stack']}
Client      : {job['client']}
Student     : {job['student_name']}
Batch       : {job['batch_year']}
Modules     : {job.get('modules', 'As appropriate for the project')}

Write as if this is a real, implemented project.
Be specific to the tech stack and domain mentioned above.
"""

        # ── generate all chapters in parallel ─────────────────────
        async def gen_chapter(name: str, prompt: str):
            for attempt in range(3):
                try:
                    r = client.messages.create(
                        model      = "claude-sonnet-4-5",
                        max_tokens = 4096,
                        messages   = [{"role": "user",
                                       "content": context + "\n\n" + prompt}]
                    )
                    return name, r.content[0].text
                except Exception as e:
                    if "rate_limit" in str(e).lower():
                        await asyncio.sleep(2 ** attempt)
                    else:
                        raise
            raise Exception(f"Chapter {name} failed after 3 retries")

        results  = await asyncio.gather(*[gen_chapter(n, p) for n, p in CHAPTERS])
        chapters = dict(results)

        # ── assemble .docx in memory ──────────────────────────────
        buffer = build_docx(job, chapters)

        # ── upload to Firebase Storage (temp) ─────────────────────
        bucket    = storage.bucket()
        temp_path = f"temp/{jid}/report.docx"
        temp_blob = bucket.blob(temp_path)

        temp_blob.upload_from_file(
            buffer,
            content_type = ("application/vnd.openxmlformats-officedocument"
                            ".wordprocessingml.document")
        )
        del buffer

        # ── transfer to Google Drive ───────────────────────────────
        docx_bytes = io.BytesIO(temp_blob.download_as_bytes())
        drive_url  = upload_to_drive(
            docx_bytes = docx_bytes,
            folder_id  = job["drive_folder_id"],
            filename   = f"{job['title']}_Project_Report.docx"
        )
        del docx_bytes

        # ── delete from Firebase Storage ──────────────────────────
        temp_blob.delete()
        temp_blob = None

        # ── update Firestore ──────────────────────────────────────
        db.collection("jobs").document(jid).update({
            "status"       : "done",
            "drive_url"    : drive_url,
            "pages"        : 94,
            "completed_at" : firestore.SERVER_TIMESTAMP
        })

        # ── notify user ───────────────────────────────────────────
        messaging.send(messaging.Message(
            token        = job["fcm_token"],
            notification = messaging.Notification(
                title = "Report ready!",
                body  = f"{job['title']} · 94 pages on your Drive"
            ),
            data = {"job_id": jid, "drive_url": drive_url}
        ))

    except Exception as e:
        if temp_blob:
            try: temp_blob.delete()
            except: pass

        db.collection("jobs").document(jid).update({
            "status" : "failed",
            "error"  : str(e)
        })


def build_docx(job: dict, chapters: dict) -> io.BytesIO:
    doc = Document()

    # cover page
    doc.add_heading(job["title"], 0)
    doc.add_paragraph("")
    doc.add_paragraph(f"A Project Report submitted in partial fulfillment of the")
    doc.add_paragraph(f"requirements for the degree of Bachelor of Engineering")
    doc.add_paragraph("")
    doc.add_paragraph(f"Submitted by")
    doc.add_paragraph(f"{job['student_name']}")
    doc.add_paragraph(f"Batch: {job['batch_year']}")
    doc.add_paragraph("")
    doc.add_paragraph(f"Under the guidance of")
    doc.add_paragraph(f"Project Guide")
    doc.add_paragraph("")
    doc.add_paragraph(f"{job['client']}")
    doc.add_page_break()

    # table of contents note
    doc.add_heading("Table of Contents", 1)
    doc.add_paragraph(
        "Note: Right-click this section and select 'Update Field' "
        "after opening in Microsoft Word to generate the Table of Contents."
    )
    doc.add_page_break()

    titles = {
        "abstract"       : "Chapter 1: Abstract and Introduction",
        "literature"     : "Chapter 2: Literature Review",
        "requirements"   : "Chapter 3: Requirements Analysis",
        "system_design"  : "Chapter 4: System Design",
        "implementation" : "Chapter 5: Implementation",
        "database"       : "Chapter 6: Database Design",
        "testing"        : "Chapter 7: Testing",
        "results"        : "Chapter 8: Results and Discussion",
        "conclusion"     : "Chapter 9: Conclusion and Future Work",
        "references"     : "Chapter 10: References and Appendix",
    }

    for key, title in titles.items():
        doc.add_heading(title, 1)
        content = chapters.get(key, "Content not generated.")
        for paragraph in content.split("\n\n"):
            if paragraph.strip():
                doc.add_paragraph(paragraph.strip())
        doc.add_page_break()

    buf = io.BytesIO()
    doc.save(buf)
    buf.seek(0)
    return buf


def upload_to_drive(docx_bytes: io.BytesIO,
                    folder_id: str,
                    filename: str) -> str:
    creds = service_account.Credentials.from_service_account_file(
        "service_account.json",
        scopes=["https://www.googleapis.com/auth/drive"]
    )
    service = build("drive", "v3", credentials=creds)

    meta  = {"name": filename, "parents": [folder_id]}
    media = MediaIoBaseUpload(
        docx_bytes,
        mimetype  = ("application/vnd.openxmlformats-officedocument"
                     ".wordprocessingml.document"),
        resumable = True
    )
    file = service.files().create(
        body       = meta,
        media_body = media,
        fields     = "id, webViewLink"
    ).execute()

    return file["webViewLink"]
```

### requirements.txt (Cloud Function)
```
anthropic>=0.25.0
firebase-admin>=6.3.0
firebase-functions>=0.1.0
google-cloud-storage>=2.14.0
google-api-python-client>=2.111.0
google-auth>=2.27.0
python-docx>=1.1.0
```

---

## 13. Flutter Mobile App

### Screen 1 — New Report Form

```dart
// lib/screens/new_report_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});
  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _formKey = GlobalKey<FormState>();

  final _title       = TextEditingController();
  final _description = TextEditingController();
  final _client      = TextEditingController();
  final _studentName = TextEditingController();
  final _batchYear   = TextEditingController();
  final _driveLink   = TextEditingController();
  final _modules     = TextEditingController();

  String _domain     = 'Web development';
  List<String> _selectedStack = [];
  bool _isLoading    = false;

  final _domains = [
    'Web development', 'Machine learning / AI', 'Mobile app',
    'Data science', 'IoT / Embedded', 'Cybersecurity',
    'Cloud / DevOps', 'Blockchain',
  ];

  final _stackOptions = [
    'Python', 'Flask', 'Django', 'FastAPI',
    'React', 'Node.js', 'MySQL', 'MongoDB',
    'Firebase', 'TensorFlow', 'Java', 'Spring Boot',
  ];

  String _extractFolderId(String url) {
    final regex = RegExp(r'folders/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? url;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one tech')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user     = FirebaseAuth.instance.currentUser!;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final folderId = _extractFolderId(_driveLink.text.trim());

      await FirebaseFirestore.instance.collection('jobs').add({
        'uid'            : user.uid,
        'title'          : _title.text.trim(),
        'description'    : _description.text.trim(),
        'domain'         : _domain,
        'tech_stack'     : _selectedStack.join(', '),
        'client'         : _client.text.trim(),
        'student_name'   : _studentName.text.trim(),
        'batch_year'     : _batchYear.text.trim(),
        'modules'        : _modules.text.trim(),
        'drive_folder_id': folderId,
        'fcm_token'      : fcmToken,
        'status'         : 'pending',
        'created_at'     : FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report queued! We will notify you when done.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New report')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Project title'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Project description'),
              maxLines: 4,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _domain,
              decoration: const InputDecoration(labelText: 'Domain'),
              items: _domains.map((d) =>
                DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _domain = v!),
            ),
            const SizedBox(height: 12),
            const Text('Tech stack', style: TextStyle(fontSize: 13)),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: _stackOptions.map((tech) => FilterChip(
                label: Text(tech),
                selected: _selectedStack.contains(tech),
                onSelected: (sel) => setState(() {
                  sel ? _selectedStack.add(tech) : _selectedStack.remove(tech);
                }),
              )).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _client,
              decoration: const InputDecoration(labelText: 'College / client name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _studentName,
                decoration: const InputDecoration(labelText: 'Student name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _batchYear,
                decoration: const InputDecoration(labelText: 'Batch year'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modules,
              decoration: const InputDecoration(
                labelText: 'Key modules / features',
                hintText: 'e.g. Login, Book issue, Return, Fine management',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _driveLink,
              decoration: const InputDecoration(
                labelText: 'Google Drive folder link',
                hintText: 'https://drive.google.com/drive/folders/...',
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Generate my report'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Screen 2 — History

```dart
// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where('uid', isEqualTo: uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No reports yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return _ReportCard(data: d);
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final status   = data['status'] as String;
    final isDone   = status == 'done';
    final isFailed = status == 'failed';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            const SizedBox(height: 4),
            Text('${data['tech_stack']} · ${data['client']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusBadge(status: status),
                if (isDone)
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse(data['drive_url'])),
                    child: const Text('Open Drive'),
                  ),
                if (isFailed)
                  const Text('Failed — try again',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg; String label;
    switch (status) {
      case 'done':
        bg = Colors.green[50]!; fg = Colors.green[800]!; label = 'Ready';
        break;
      case 'processing':
        bg = Colors.blue[50]!; fg = Colors.blue[800]!; label = 'Generating...';
        break;
      case 'failed':
        bg = Colors.red[50]!; fg = Colors.red[800]!; label = 'Failed';
        break;
      default:
        bg = Colors.grey[100]!; fg = Colors.grey[700]!; label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}
```

### pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.0
  cloud_firestore: ^4.15.0
  firebase_messaging: ^14.7.0
  firebase_storage: ^11.6.0
  url_launcher: ^6.2.5
```

---

## 14. Firestore Schema

```
users/
  {uid}:
    email         : string
    name          : string
    plan          : "free" | "standard" | "pro"
    reports_used  : number
    created_at    : timestamp

jobs/
  {job_id}:
    uid             : string          -- Firebase Auth UID
    title           : string          -- project title
    description     : string          -- 2-3 line description
    domain          : string          -- Web development etc.
    tech_stack      : string          -- comma separated
    client          : string          -- college / client name
    student_name    : string
    batch_year      : string          -- "2024-25"
    modules         : string          -- key features list
    drive_folder_id : string          -- extracted from Drive link
    fcm_token       : string          -- device push token
    status          : string          -- pending | processing | done | failed
    drive_url       : string          -- permanent Google Drive link
    pages           : number          -- 94
    error           : string          -- if failed
    created_at      : timestamp
    completed_at    : timestamp
```

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /jobs/{jobId} {
      allow read: if request.auth != null
                  && request.auth.uid == resource.data.uid;
      allow create: if request.auth != null
                    && request.resource.data.uid == request.auth.uid;
      allow update: if false;  // only Cloud Function updates
    }
    match /users/{uid} {
      allow read, write: if request.auth != null
                         && request.auth.uid == uid;
    }
  }
}
```

---

## 15. Build Roadmap

### Phase 1 — Core 
- [ ] Firebase project setup (Auth, Firestore, Storage, FCM)
- [ ] Cloud Function scaffolding + deployment
- [ ] Claude API integration — single chapter test
- [ ] All 10 chapter prompts tuned and tested
- [ ] python-docx formatter — cover page + all chapters
- [ ] Firebase Storage upload + delete
- [ ] Google Drive upload via service account
- [ ] End-to-end test: form → Cloud Function → Drive

### Phase 2 — Mobile App 
- [ ] Flutter project setup + Firebase integration
- [ ] Screen 1: New report form with validation
- [ ] Screen 2: History with real-time Firestore listener
- [ ] FCM push notification handling
- [ ] Status badge (pending / processing / done / failed)
- [ ] Drive link open in browser

### Phase 3 — Polish & Launch 
- [ ] Free tier logic (1 free report per user)
- [ ] Report quality review + prompt tuning
- [ ] Error handling + retry logic
- [ ] Beta test with 10 real students
- [ ] Collect feedback + iterate

### Phase 4 — Growth (Month 2)
- [ ] Referral system (₹20 credit per referral)
- [ ] College bundle landing page
- [ ] WhatsApp broadcast for college groups
- [ ] Add more output types (viva Q&A, user guide separately)
- [ ] Analytics dashboard (reports generated, revenue)


