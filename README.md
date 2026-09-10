# Supabase PostgreSQL image contract

This image extends `supabase/postgres:17.6.1.136` for the `self-hosted/v0.8.1` component bundle. The base digest is
pinned in `Dockerfile`. Upstream PostgreSQL, extensions, configuration, migrations and privilege dropping
remain in place. Wodby adds its operational command interface and a final initialization/import hook.

## Image and development

Image repository: `wodby/supabase-postgres`. Tags use `17-<release>`, independently of the ordinary PostgreSQL image release cycle. The first planned release is `17-0.1.0`.

Build and run recovery tests with Wodby CLI 2.10.0, Docker and Python 3 installed:

```sh
bash scripts/test-supabase-ci.sh
```

CI tests native amd64 and arm64 images on pull requests. The main branch publishes the moving `17` tag, and release tags publish `17-<release>` after both architecture tests pass. Publishing requires `DOCKER_USERNAME` and `DOCKER_PASSWORD` repository or organization secrets.

## Startup and persistence

Set `POSTGRES_PASSWORD` and `JWT_SECRET`. Keep `POSTGRES_USER=supabase_admin`, `POSTGRES_DB=postgres` and
`PGDATA=/var/lib/postgresql/data`. The default command starts PostgreSQL with the upstream configuration.

Mount one persistent volume at `/var/lib/postgresql`. It contains `data/`, `wodby-keys/` and initialization markers.
The upstream encryption-key path `/etc/postgresql-custom/pgsodium_root.key` points into `wodby-keys/`.
Keeping database data and keys together lets a fresh-volume import replace both atomically. Do not mount a separate
volume over `/etc/postgresql-custom` or mount only `data/`.

Failed initialization or import leaves a pending marker and refuses subsequent normal startup. Retry with a fresh
volume; do not remove the marker to promote a partially restored database. Existing databases also refuse startup
when their encryption key is missing. The image is not an in-place conversion of a plain PostgreSQL volume.

## Operations

```sh
make check-ready host=database max_try=30 wait_seconds=2
make backup host=database filepath=/var/lib/postgresql/backup.tar.gz
make backup host=database filepath=/var/lib/postgresql/backup.tar.gz ignore='public.cache;public.sessions'
```

The image entrypoint dispatches `make` to its operation definitions. Backup containers need the database volume
mounted and the database host/password configured. `make query query=...` and `make query-silent query=...` provide
SQL access. Generic create/drop database/user actions are intentionally not exposed for Supabase's reserved resources.

Backups contain custom-format dumps of all non-template databases, roles and memberships, the root encryption key,
and a checksummed inventory. Exclusions omit table data, not table definitions, across matching databases. Dumps
are staged beside the destination, so allow space for both dumps and the resulting archive. Backups contain secrets;
store and transfer them through protected storage.

## Wodby import

The service import workflow extracts a `.tar.gz` or `.tgz` backup into a read-only `/wodby/import` mount and sets
`SUPABASE_IMPORT_ON_INIT=1` on a fresh replacement volume. Import supports only this image's checksummed backup
format from the exact same upstream bundle. Ordinary SQL dumps and backups from other bundles need a separate
migration procedure.

Before starting PostgreSQL, the wrapper validates every backup file and installs the saved root key. After upstream
initialization, the final hook restores roles and every database through the temporary Unix-socket server. TCP
connections become available only after successful import. The built-in service logins are reset to the target
`POSTGRES_PASSWORD`; custom role passwords are preserved. Database JWT settings follow the target `JWT_SECRET`.
An unchanged import mount is safe across restart; it is not replayed against the existing database.

`make import source=/path/to/extracted-bundle host=/var/run/postgresql` is restricted to fresh initialization;
use the Wodby service import workflow for normal operations. It deliberately refuses live-database import.

A coordinated recovery also needs matching application tokens and stored objects. Stop application writers when
capturing that recovery point. Database import does not restore filesystem/S3 objects or application signing and
encryption tokens. Preserve the original encryption tokens required by copied application data; rotate client-facing
API keys separately when appropriate. A Helm rollback cannot undo database migrations.

## Validation and upstream ownership

`tests/supabase.sh` checks fresh startup, a separate-container backup, read-only init import with a different target
password, custom roles, RLS, Vault decryption, Auth data, Storage-schema fixture data, exclusions, restart and failed
restore recovery. The Supabase workflow runs it on both amd64 and arm64 through Wodby CLI. Full application API and
object-store acceptance is a separate stack test.

Initialization SQL is adapted from [Supabase self-hosted/v0.8.1](https://github.com/supabase/supabase/tree/self-hosted/v0.8.1/docker/volumes/db),
commit `8c7a4d9dbbaf8b552893822e89d7bf06f33f9220`. Its license is retained in `supabase/UPSTREAM-LICENSE`.
