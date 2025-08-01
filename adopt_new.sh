#!/usr/bin/env bash

set -e # Exit immediately if a command exits with a non-zero status

DOTFILES="${HOME}/dotfiles"
TARGET_CONFIG="${HOME}/.config"
CONFIG_IGNORE_FILE="${DOTFILES}/.config_ignore"

echo "--- Starting new dotfiles adoption script ---"
echo "---"

# Ensure the target ~/.config directory exists.
mkdir -p "${TARGET_CONFIG}"

# Function to check a directory for any symlinks (absolute or relative)
# This uses a portable method to check for output from find
check_for_any_symlinks() {
  local dir_path="$1"
  find "${dir_path}" -type l | grep -q .
}

# Function to check a directory for any files (recursively)
# This is a portable way to check for a non-empty directory.
check_for_any_files() {
  local dir_path="$1"
  find "${dir_path}" -mindepth 1 | grep -q .
}

# =======================
#   Intra-Package Adoption Phase
# =======================
# This phase finds new files/folders inside already stowed directories and
# moves them into the dotfiles repository.
echo "1. Intra-Package Adoption: Moving new files into existing packages..."
for package_path in "${DOTFILES}"/*; do
  package_name="$(basename "${package_path}")"
  if ! [ -d "${package_path}" ] || [ "${package_name}" = "." ] || [ "${package_name}" = ".." ] || [ "${package_name}" = ".git" ]; then
    continue
  fi

  if [ ! -d "${package_path}/.config" ]; then continue; fi

  target_dir="${TARGET_CONFIG}/${package_name}"
  source_dir="${package_path}/.config/${package_name}"
  
  if [ ! -d "${target_dir}" ]; then continue; fi

  find "${target_dir}" -mindepth 1 -maxdepth 1 -not -type l | while IFS= read -r item_path; do
    item_name="$(basename "${item_path}")"
    if [ ! -d "${source_dir}" ]; then continue; fi

    if [ -d "${item_path}" ] && ! check_for_any_files "${item_path}"; then
        echo "[${package_name}] Skipping empty directory '${item_name}'."
        continue
    fi

    if [ -d "${item_path}" ] && check_for_any_symlinks "${item_path}"; then
        echo "[${package_name}] Skipping '${item_name}': It is a directory containing symlinks."
        continue
    fi
    
    echo "  - Found new item: '${item_name}' in package '${package_name}'"
    echo "    - Moving '${item_path}' to '${source_dir}/'"
    mv "${item_path}" "${source_dir}/"
    
  done
done
echo "Intra-package adoption complete."
echo "---"

# =======================
#   New Package Adoption Phase
# =======================
# This phase finds new, top-level directories in ~/.config and creates new
# packages for them.
echo "2. New Package Adoption: Creating new packages for unmanaged items..."

# Prepare the ignore patterns for grep.
IGNORE_PATTERNS_FILE=$(mktemp)
trap "rm -f ${IGNORE_PATTERNS_FILE}" EXIT # Clean up the temp file on exit

if [ -f "${CONFIG_IGNORE_FILE}" ]; then
  # Read the ignore file and sanitize lines for grep
  grep -v '^\s*#' "${CONFIG_IGNORE_FILE}" | grep -v '^\s*$' > "${IGNORE_PATTERNS_FILE}"
fi

find "${TARGET_CONFIG}" -mindepth 1 -maxdepth 1 -not -type l | while IFS= read -r item_path; do
    item_name="$(basename "${item_path}")"
    package_path="${DOTFILES}/${item_name}"
    
    # Check against the ignore file using grep
    if [ -s "${IGNORE_PATTERNS_FILE}" ] && echo "$item_name" | grep -q -x -F -f "${IGNORE_PATTERNS_FILE}"; then
        echo "Skipping package '${item_name}': Found in ignore file."
        continue
    fi
    
    if [ -d "${package_path}" ]; then
        echo "Skipping package '${item_name}': A corresponding package already exists."
        continue
    fi
    
    if [ -L "${item_path}" ]; then
        echo "Skipping package '${item_name}': It is a symlink (likely already managed)."
        continue
    fi
    
    if [ -d "${item_path}" ] && ! check_for_any_files "${item_path}"; then
        echo "Skipping empty directory '${item_name}'."
        continue
    fi

    if [ -d "${item_path}" ] && check_for_any_symlinks "${item_path}"; then
        echo "Skipping package '${item_name}': Contains symlinks."
        continue
    fi
    
    echo "== Adopting new package: ${item_name} =="
    
    echo "  - Creating new package directory: '${package_path}/.config/'"
    mkdir -p "${package_path}/.config/"
    echo "  - Moving unmanaged item '${item_path}' to '${package_path}/.config/'"
    mv "${item_path}" "${package_path}/.config/"
    
    echo "Adoption complete for '${item_name}'."
    echo "---"
done

echo "New package adoption complete."
echo "---"

echo "--- Script finished successfully! ---"
