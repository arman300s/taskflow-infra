# taskflow-status - small status page of the TaskFlow system
FROM python:3.12-slim

LABEL org.opencontainers.image.title="taskflow-status" \
      org.opencontainers.image.description="Status page of the TaskFlow system" \
      org.opencontainers.image.source="https://github.com/arman300s/taskflow-infra"

# run as an unprivileged user, never as root
RUN useradd --system --no-create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY status_app.py .

ENV PORT=8080 \
    API_URL=http://tf-app:8000 \
    NODES=tf-web,tf-app,tf-db \
    PYTHONUNBUFFERED=1
EXPOSE 8080
USER app

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2)"

CMD ["python", "status_app.py"]
