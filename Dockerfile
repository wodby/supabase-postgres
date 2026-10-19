ARG SUPABASE_IMAGE=supabase/postgres:17.11.0.004@sha256:b15d862126dd2dac02da524696ccfde2dcce2ceaee0a58973b2727befe492706
FROM ${SUPABASE_IMAGE}

USER root
# Upgrade inherited packages even when their existing versions satisfy dependencies.
RUN set -ex; \
    apk upgrade --no-cache; \
    apk add --no-cache make python3 && \
    test ! -e /etc/postgresql-custom/pgsodium_root.key && \
    ln -s /var/lib/postgresql/wodby-keys/pgsodium_root.key /etc/postgresql-custom/pgsodium_root.key
COPY supabase/init-scripts/ /docker-entrypoint-initdb.d/init-scripts/
COPY supabase/migrations/ /docker-entrypoint-initdb.d/migrations/
COPY supabase/init-hook.sh /docker-entrypoint-initdb.d/zz-wodby-import.sh
COPY supabase/actions.mk /usr/local/share/wodby/supabase-actions.mk
COPY supabase/ops.py /usr/local/bin/supabase-ops
COPY supabase/entrypoint.sh /usr/local/bin/wodby-supabase-entrypoint
COPY supabase/UPSTREAM-LICENSE /usr/local/share/wodby/SUPABASE-LICENSE
RUN chmod 0755 /usr/local/bin/supabase-ops /usr/local/bin/wodby-supabase-entrypoint \
    /docker-entrypoint-initdb.d/zz-wodby-import.sh
ENV POSTGRES_MAJOR_VER=17 JWT_EXP=3600
ENTRYPOINT ["wodby-supabase-entrypoint"]
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf", "-c", "log_min_messages=warning"]
