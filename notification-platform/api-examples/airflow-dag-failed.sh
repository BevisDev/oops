# Airflow — DAG failed

```bash
curl -sS -X POST https://notif.company.com/notification/notify \
  -H "X-Api-Key: $AIRFLOW_NOTIF_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: airflow:dag.failed:${DAG_ID}:${RUN_ID}" \
  -d @- <<EOF
{
  "event_type": "dag.failed",
  "severity": "error",
  "idempotency_key": "airflow:dag.failed:${DAG_ID}:${RUN_ID}",
  "correlation_id": "${RUN_ID}",
  "payload": {
    "dag_id": "${DAG_ID}",
    "run_id": "${RUN_ID}",
    "logical_date": "${LOGICAL_DATE}",
    "error": "${ERROR_MESSAGE}",
    "log_url": "${LOG_URL}",
    "env": "prod"
  }
}
EOF
```

Python callback (Airflow):

```python
import json, urllib.request, os

def on_failure_callback(context):
    dag = context["dag"].dag_id
    run_id = context["run_id"]
    body = {
        "event_type": "dag.failed",
        "severity": "error",
        "idempotency_key": f"airflow:dag.failed:{dag}:{run_id}",
        "correlation_id": run_id,
        "payload": {
            "dag_id": dag,
            "run_id": run_id,
            "logical_date": str(context["logical_date"]),
            "error": str(context.get("exception")),
            "log_url": context.get("task_instance").log_url,
            "env": os.getenv("ENV", "prod"),
        },
    }
    req = urllib.request.Request(
        os.environ["NOTIF_URL"] + "/notification/notify",
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "X-Api-Key": os.environ["NOTIF_API_KEY"],
        },
        method="POST",
    )
    urllib.request.urlopen(req, timeout=5)
```
