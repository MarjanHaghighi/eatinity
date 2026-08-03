#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAMBDA_DIR="$PROJECT_DIR/lambda"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/eatinity-lambda-build.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  }
}

need python
need zip

package_simple() {
  local folder="$1" archive="$2"
  [[ -d "$LAMBDA_DIR/$folder" ]] || {
    printf 'Missing Lambda folder: %s\n' "$folder" >&2
    exit 1
  }
  rm -f "$LAMBDA_DIR/$archive.zip"
  (
    cd "$LAMBDA_DIR/$folder"
    zip -qr "$LAMBDA_DIR/$archive.zip" . -x '*__pycache__*' '*.pyc'
  )
}

package_stripe() {
  local folder="$1" handler="$2" archive="$3"
  local staging="$BUILD_DIR/$archive"
  mkdir -p "$staging"

  # Explicit Linux/Python 3.12 targeting makes packages reproducible even when
  # this script is launched from Git Bash on Windows.
  python -m pip install \
    --disable-pip-version-check \
    --platform manylinux2014_x86_64 \
    --implementation cp \
    --python-version 3.12 \
    --only-binary=:all: \
    --requirement "$LAMBDA_DIR/stripe_requirements.txt" \
    --target "$staging"

  cp "$LAMBDA_DIR/$folder/$handler" "$staging/$handler"
  rm -f "$LAMBDA_DIR/$archive.zip"
  (
    cd "$staging"
    zip -qr "$LAMBDA_DIR/$archive.zip" . -x '*__pycache__*' '*.pyc'
  )
}

package_simple products get_products
package_simple admin_menu admin_menu
package_simple admin_orders admin_orders
package_simple admin_users admin_users
package_simple sales_reports sales_reports
package_simple admin_audit admin_audit
package_simple user_profile user_profile
package_stripe stripe_checkout create_checkout_session.py stripe_checkout
package_stripe stripe_webhook process_stripe_webhook.py stripe_webhook

printf 'Built Lambda packages under %s\n' "$LAMBDA_DIR"
