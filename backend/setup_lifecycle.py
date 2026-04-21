# setup_lifecycle.py
# Run once during project setup to add a safety-net lifecycle rule
# to Firebase Storage so temp files are auto-deleted after 1 day
# even if the Cloud Function's explicit delete call fails.
#
# Usage:
#   GOOGLE_APPLICATION_CREDENTIALS=service_account.json python setup_lifecycle.py

import os
from google.cloud import storage as gcs


def set_lifecycle_policy(bucket_name: str) -> None:
    client = gcs.Client()
    bucket = client.bucket(bucket_name)
    bucket.lifecycle_rules = [
        {
            "action"    : {"type": "Delete"},
            "condition" : {
                "age"           : 1,           # 1 day safety net
                "matchesPrefix" : ["temp/"]
            }
        }
    ]
    bucket.patch()
    print(f"Lifecycle policy set on bucket: {bucket_name}")


if __name__ == "__main__":
    bucket = os.environ.get("FIREBASE_STORAGE_BUCKET")
    if not bucket:
        raise ValueError(
            "Set FIREBASE_STORAGE_BUCKET env var, e.g. your-project.appspot.com"
        )
    set_lifecycle_policy(bucket)
