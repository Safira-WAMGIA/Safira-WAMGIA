#!/usr/bin/env bash
set -e
[[ -f /app/bootstrap.sh ]] && bash /app/bootstrap.sh
exec "$@"
