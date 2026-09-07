#!/usr/bin/env bash
#
# CSC 124 assignment submitter — Toccoa Falls College
# Students run this from their assignment folder in their Coder workspace:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/TGoetzUTF/csc124-tools/main/submit.sh)
#
# It is safe to run as many times as you want.

set -u

INSTRUCTOR_GH="TGoetzUTF"

say()  { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31m  ✗ %s\033[0m\n' "$*"; exit 1; }

say "CSC 124 Assignment Submitter"
echo "  Folder being submitted: $(pwd)"

# ── 1. Make sure git knows who you are ───────────────────────────────
if [ -z "$(git config --global user.name || true)" ]; then
  read -rp "  Your full name (for your commits): " gitname
  [ -n "$gitname" ] || fail "A name is required."
  git config --global user.name "$gitname"
fi
if [ -z "$(git config --global user.email || true)" ]; then
  read -rp "  Your TFC email address: " gitemail
  [ -n "$gitemail" ] || fail "An email is required."
  git config --global user.email "$gitemail"
fi
ok "Committing as: $(git config --global user.name) <$(git config --global user.email)>"

# ── 2. Make sure you are signed in to GitHub ─────────────────────────
if ! gh auth status >/dev/null 2>&1; then
  say "You need to sign in to GitHub (one time only)."
  echo "  A one-time code will appear below. Open the link in a new browser"
  echo "  tab, sign in to GitHub, and type in the code."
  gh auth login --web --git-protocol https || fail "GitHub sign-in did not finish. Run the submitter again."
fi
gh auth setup-git >/dev/null 2>&1
ok "Signed in to GitHub as: $(gh api user -q .login)"

# ── 3. Which assignment is this? ─────────────────────────────────────
read -rp "  Assignment name (e.g. week2): " raw
assignment=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
[ -n "$assignment" ] || fail "Assignment name is required (letters and numbers only, e.g. week2)."
repo="csc124-$assignment"

# ── 4. Save your work as a commit ────────────────────────────────────
if [ ! -d .git ]; then
  git init -b main >/dev/null 2>&1 || git init >/dev/null
fi
git add -A
if git diff --cached --quiet 2>/dev/null && git rev-parse HEAD >/dev/null 2>&1; then
  ok "No new changes since your last submission — pushing what's here."
else
  git commit -m "Submission: $repo ($(date '+%Y-%m-%d %H:%M'))" >/dev/null || fail "Nothing to commit. Are your files in this folder? (run: ls)"
  ok "Work saved as a commit."
fi

# ── 5. Create the repository on GitHub (first time) or update it ─────
me=$(gh api user -q .login)
if git remote get-url origin >/dev/null 2>&1; then
  git push -u origin HEAD >/dev/null 2>&1 || fail "Push failed. Ask your instructor for help and include this screen."
elif gh repo view "$me/$repo" >/dev/null 2>&1; then
  git remote add origin "https://github.com/$me/$repo.git"
  git push -u origin HEAD >/dev/null 2>&1 || fail "Push failed. Ask your instructor for help and include this screen."
else
  gh repo create "$repo" --private --source=. --push >/dev/null 2>&1 || fail "Could not create the repository on GitHub."
fi
ok "Your code is on GitHub (private repository: $me/$repo)."

# ── 6. Give your instructor access ───────────────────────────────────
gh api --method PUT "repos/$me/$repo/collaborators/$INSTRUCTOR_GH" >/dev/null 2>&1 \
  && ok "Instructor ($INSTRUCTOR_GH) has been given access." \
  || echo "  (Could not auto-invite the instructor — invite $INSTRUCTOR_GH under the repo's Settings → Collaborators.)"

# ── 7. Your submission link ──────────────────────────────────────────
say "DONE! Submit this link in Canvas:"
printf '\n  \033[1;33mhttps://github.com/%s/%s\033[0m\n\n' "$me" "$repo"
