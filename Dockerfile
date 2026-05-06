FROM python:3.12-slim

WORKDIR /app

ENV PYTHONPATH=/app/src
ENV PYTHONUNBUFFERED=1

COPY pyproject.toml ./
COPY src ./src

RUN pip install --no-cache-dir asyncpg temporalio structlog hvac

CMD ["python", "-m", "order_demo.workers.order_worker.main"]
