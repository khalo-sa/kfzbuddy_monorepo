#!/usr/bin/env bash
set -euo pipefail

# === Choose environment (reads .env.production.local or .env.staging.local) ===
echo "Select environment:"
select ENV in production staging; do
  case $ENV in
    production|staging) break ;;
    *) echo "Invalid choice";;
  esac
done

ENV_FILE=".env.${ENV}.local"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Environment file '$ENV_FILE' not found in repo root."
  exit 1
fi

# Export all vars in the file, then un-export
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -z "${POSTGRES_URL:-}" ]]; then
  echo "❌ POSTGRES_URL not found in $ENV_FILE"
  exit 1
fi

# === Local Docker Postgres target ============================================
LOCAL_CONTAINER="pg16"   # docker ps --format '{{.Names}}'
LOCAL_USER="postgres"
# Get current git branch name and sanitize it for PostgreSQL database naming
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
# Sanitize branch name: replace invalid chars with underscores, ensure it starts with a letter
SANITIZED_BRANCH=$(echo "$CURRENT_BRANCH" | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/^[0-9]/branch_&/')
LOCAL_DB="kfzbuddy_${ENV}_${SANITIZED_BRANCH}"            # kfzbuddy_production_main / kfzbuddy_staging_feature_branch

echo "Cloning remote ($ENV) → local DB '$LOCAL_DB' in container '$LOCAL_CONTAINER'"

# Check if local DB already exists
EXISTS=$(docker exec -i "$LOCAL_CONTAINER" psql -U "$LOCAL_USER" -tAc \
  "SELECT 1 FROM pg_database WHERE datname='${LOCAL_DB}'" || true)

if [[ "$EXISTS" == "1" ]]; then
  echo "⚠️  Database '$LOCAL_DB' already exists in container '$LOCAL_CONTAINER'"
  echo "This will overwrite all existing data in the local database."
  read -p "Do you want to continue? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Operation cancelled."
    exit 1
  fi
  echo "🗑️  Dropping existing database '$LOCAL_DB'..."
  docker exec -i "$LOCAL_CONTAINER" dropdb -U "$LOCAL_USER" "$LOCAL_DB"
fi

echo "Creating local DB '$LOCAL_DB'..."
docker exec -i "$LOCAL_CONTAINER" createdb -U "$LOCAL_USER" "$LOCAL_DB"

# === Dump from remote URL and restore into local =============================
# NOTE: We pass the full URL directly via --dbname (works for postgresql:// and postgres://)
docker run --rm postgres:16 \
  pg_dump --verbose -F c --dbname="$POSTGRES_URL" \
| docker exec -i "$LOCAL_CONTAINER" pg_restore \
    -U "$LOCAL_USER" -d "$LOCAL_DB" \
    --clean --if-exists --no-owner --no-privileges -v

echo "✅ Done. Local database '$LOCAL_DB' now mirrors remote ($ENV)."