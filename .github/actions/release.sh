#!/usr/bin/env bash
set -euo pipefail

# Publish only from the main branch or a release tag, using the tested architecture tags.
if [[ "${GITHUB_REF}" != refs/heads/main && "${GITHUB_REF}" != refs/tags/* ]]; then
    exit 0
fi
minor_ver="${POSTGRES_VER}"
major_ver="${minor_ver%.*}"
image_revision=''
tags=("${minor_ver}")
if [[ -n "${LATEST_MAJOR:-}" ]]; then tags+=("${major_ver}"); fi
if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
    image_revision="${GITHUB_REF##*/}"
    for i in "${!tags[@]}"; do tags[$i]="${tags[$i]}-${image_revision}"; done
elif [[ -n "${LATEST_ALIAS:-}" ]]; then
    tags+=("${LATEST_ALIAS}")
fi
for tag in "${tags[@]}"; do
    make buildx-imagetools-create TAG="${major_ver}" IMAGE_REVISION="${image_revision}" IMAGETOOLS_TAG="${tag}"
done
