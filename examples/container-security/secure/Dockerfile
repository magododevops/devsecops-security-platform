FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 \
       --gid appgroup \
       --no-create-home appuser

COPY --chown=10001:10001 app.py /app/app.py

USER 10001:10001

CMD ["python", "/app/app.py"]
