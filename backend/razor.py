import hmac, hashlib, json, requests

secret = "wh_secret_projdoc_2024_xk9m"

payload = {
    "event": "payment_link.paid",
    "payload": {
        "payment_link": {
            "entity": {
                "customer": {
                    "email": "pareekharsh15@gmail.com"
                }
            }
        },
        "payment": {
            "entity": {
                "id": "pay_test123",
                "email": "pareekharsh15@gmail.com",
                "amount": 10000
            }
        }
    }
}

# Exact bytes used for both signature and request body
body_bytes = json.dumps(payload, separators=(',', ':')).encode()

sig = hmac.new(secret.encode(), body_bytes, hashlib.sha256).hexdigest()

response = requests.post(
    "https://razorpay-webhook-w5jfsfdr4a-uc.a.run.app",
    data=body_bytes,
    headers={
        "Content-Type": "application/json",
        "X-Razorpay-Signature": sig
    }
)

print("Status:", response.status_code)
print("Response:", response.text)