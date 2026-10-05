import gzip
import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

random.seed(42)

PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = PROJECT_ROOT / "data" / "generated"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

PRODUCTS = [
    ("P001", "Carnet", 850),
    ("P002", "Lampe", 2490),
    ("P003", "Sac", 3990),
    ("P004", "Gourde", 1590),
]
COUNTRIES = ["FR", "BE", "DE", "ES"]


def make_transaction(number):
    items = []
    for product_id, name, price_cents in random.sample(PRODUCTS, random.randint(1, 3)):
        quantity = random.randint(1, 3)
        items.append({
            "product_id": product_id,
            "name": name,
            "quantity": quantity,
            "unit_price": price_cents / 100,
        })

    total_cents = sum(
        round(item["unit_price"] * 100) * item["quantity"]
        for item in items
    )
    timestamp = datetime(2026, 9, 1, tzinfo=timezone.utc) + timedelta(
        minutes=number * 17
    )

    return {
        "transaction_id": f"TX-{number:06d}",
        "customer_info": {
            "id": f"C-{random.randint(1, 60):04d}",
            "email": f"client{number}@example.com",
            "country": random.choice(COUNTRIES),
        },
        "items": items,
        "total_amount": total_cents / 100,
        "event_timestamp": timestamp.isoformat(),
    }


for filename, numbers in [
    ("transactions_s3.json.gz", range(1, 501)),
    ("transactions_internal.json.gz", range(501, 1001)),
]:
    path = OUTPUT_DIR / filename
    with gzip.open(path, "wt", encoding="utf-8") as file:
        for number in numbers:
            file.write(json.dumps(make_transaction(number), ensure_ascii=False) + "\n")
    print(f"Créé : {path} ({len(numbers)} transactions)")