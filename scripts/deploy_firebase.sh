#!/usr/bin/env bash
# Firebase full deployment script
# Deploys: database security rules + admin portal hosting
#
# Usage:
# bash scripts/deploy_firebase.sh            # deploy everything
# bash scripts/deploy_firebase.sh --rules    # rules only
# bash scripts/deploy_firebase.sh --hosting  # hosting only
#
# Pre-requisites:
# npm install -g firebase-tools
# firebase login
# firebase use --add  (select your project)
set -euo pipefail

MODE="${1:-}"

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║   Firebase Deployment Script          ║"
echo "╚═══════════════════════════════════════╝"

# Validate firebase-tools is installed
if ! command -v firebase &>/dev/null; then
  echo "ERROR: firebase-tools not found."
  echo "Run: npm install -g firebase-tools && firebase login"
  exit 1
fi

# Show active project
echo ""
echo "Active Firebase project:"
firebase use
echo ""

deploy_rules() {
  echo "▶ Deploying database security rules..."
  if [ ! -f "database.rules.json" ]; then
    echo "ERROR: database.rules.json not found in project root"
    exit 1
  fi
  firebase deploy --only database
  echo "✓ Security rules deployed."
}

deploy_hosting() {
  echo "▶ Building admin portal..."
  if [ ! -f "admin_portal/.env.local" ]; then
    echo "ERROR: admin_portal/.env.local not found."
    echo "Copy admin_portal/.env.example to .env.local and fill in values."
    exit 1
  fi
  (cd admin_portal && npm install && npm run build)
  echo "▶ Deploying admin portal to Firebase Hosting..."
  firebase deploy --only hosting
  echo "✓ Admin portal deployed."
}

case "$MODE" in
  --rules)
    deploy_rules
    ;;
  --hosting)
    deploy_hosting
    ;;
  *)
    deploy_rules
    deploy_hosting
    ;;
esac

echo ""
echo "════════════════════════════════════════"
echo " Deployment complete."
echo ""
echo " Next manual step (one-time per admin):"
echo " Firebase Console → Realtime Database → add:"
echo '   /admins/{uid}/collegeId = "kec"'
echo "════════════════════════════════════════"
