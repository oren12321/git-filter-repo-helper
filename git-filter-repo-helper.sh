#!/usr/bin/env bash

set -Eeuo pipefail
[ -z "${DEBUG:-}" ] && DEBUG=0
[ "${DEBUG}" -eq 1 ] && set -x

usage() {
    echo "./git-filter-repo-helper.sh <git-repository-directory> <filtered-paths-file> [--dry-run]"
}

GIT_REPO_DIR="${1:-<unbound>}"
PATHS_FILTER_FILE="${2:-<unbound>}"
DRY_RUN="${3:-<unbound>}"

if [ "${GIT_REPO_DIR}" == "<unbound>" ]; then
    echo "Git reposotory argument is required"
    usage
    exit 1
fi;

if [ ! -d "${GIT_REPO_DIR}/.git" ]; then
    echo "Directory ${GIT_REPO_DIR} does not contain git reposotory"
    usage
    exit 1
fi;
GIT_REPO_DIR="$(pwd)/${GIT_REPO_DIR}"

if [ "${PATHS_FILTER_FILE}" == "<unbound>" ]; then
    echo "Paths filter file for git-filter-repo is required"
    usage
    exit 1
fi;

if [ ! -f "${PATHS_FILTER_FILE}" ]; then
    echo "${PATHS_FILTER_FILE} is not a file"
    usage
    exit 1
fi;
PATHS_FILTER_FILE="$(pwd)/${PATHS_FILTER_FILE}"

if [ "${DRY_RUN}" != "<unbound>" ] && [ "${DRY_RUN}" != "--dry-run" ]; then
    echo "Third argument should be empty or --dry-run"
    usage
    exit 1
fi;

WORK_DIR=`mktemp -d`

if [ "${DRY_RUN}" == "<unbound>" ]; then
    pushd "${GIT_REPO_DIR}" > /dev/null
    git remote remove origin
    git tag | xargs git tag -d
    popd > /dev/null
fi;

touch "${WORK_DIR}/git_log_results.txt"

pushd "${GIT_REPO_DIR}" > /dev/null
while read FILTERED_PATH; do
    # List files in ${FILTERED_PATH} including hidden files to ${WORK_DIR}/filtered_files
    shopt -s dotglob
    find "${FILTERED_PATH}" -type f >> "${WORK_DIR}/filtered_files"
    
    while read FILTERED_FILE; do
        echo "## " "${FILTERED_FILE}" >> "${WORK_DIR}/git_log_results.txt"
        
        # Git log filtered file and follow file renames
        git log --pretty=format:'%H' --name-only --follow -- "${FILTERED_FILE}" | \
            awk 'NF>0' | awk 'NR%2==0' | tee -a "${WORK_DIR}/git_log_results.txt"
        
        echo "\n\n" >> "${WORK_DIR}/git_log_results.txt"
    done < "${WORK_DIR}/filtered_files"
    
done < "${PATHS_FILTER_FILE}" > "${WORK_DIR}/PRESERVED"
popd > /dev/null

# filter unique files to preserve
mv "${WORK_DIR}/PRESERVED" "${WORK_DIR}/PRESERVED_TEMP"
awk '!a[$0]++' "${WORK_DIR}/PRESERVED_TEMP" > "${WORK_DIR}/PRESERVED"

sort -o "${WORK_DIR}/PRESERVED" "${WORK_DIR}/PRESERVED"

if [ "${DRY_RUN}" == "--dry-run" ]; then
    cat "${WORK_DIR}/PRESERVED"
    rm -rf "${WORK_DIR}"
    exit 0
fi;

pushd "${GIT_REPO_DIR}" > /dev/null
git filter-repo --paths-from-file "${WORK_DIR}/PRESERVED" --force --replace-refs delete-no-add
popd > /dev/null

# cleaning
rm -rf "${WORK_DIR}"

