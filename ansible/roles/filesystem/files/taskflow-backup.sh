#!/usr/bin/env bash
# Daily DB backup (scheduled by cron)
sudo -u postgres pg_dump taskflow > /var/backups/taskflow/db/taskflow_$(date +%F).sql
