#!/bin/sh
set -e

setup_and_migrate_db() {
    if [ "${DISABLE_DB_MIGRATIONS}" = "true" ]; then
        echo "Database setup and migrations are disabled, skipping..."
        return
    fi

    echo "Running database setup and migrations..."

    # Run setup and migration scripts
    has_schema=$(psql -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'core')" ${PG_DATABASE_URL})
    if [ "$has_schema" = "f" ]; then
        echo "Database appears to be empty, running migrations."
        NODE_OPTIONS="--max-old-space-size=1500" tsx ./scripts/setup-db.ts
        yarn database:migrate:prod
    fi

    yarn command:prod upgrade
    echo "Successfully migrated DB!"
}

register_background_jobs() {
    if [ "${DISABLE_CRON_JOBS_REGISTRATION}" = "true" ]; then
        echo "Cron job registration is disabled, skipping..."
        return
    fi

    echo "Registering background sync jobs..."
    if yarn command:prod cron:register:all; then
        echo "Successfully registered all background sync jobs!"
    else
        echo "Warning: Failed to register background jobs, but continuing startup..."
    fi
}

sync_workspace_metadata() {
    if [ "${DISABLE_WORKSPACE_METADATA_SYNC}" = "true" ]; then
        echo "Workspace metadata sync is disabled, skipping..."
        return
    fi

    echo "Syncing workspace metadata to Redis cache..."
    if yarn command:prod workspace:sync-metadata; then
        echo "Successfully synced workspace metadata!"
    else
        echo "Warning: Failed to sync workspace metadata, but continuing startup..."
        echo "Users may experience login issues until metadata is synced."
    fi
}

setup_and_migrate_db
sync_workspace_metadata
register_background_jobs

# Continue with the original Docker command
exec "$@"
