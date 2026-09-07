#!/usr/bin/env bash
#
# CSC 124 assignment submitter — University of Toccoa Falls
# Students run this from their assignment folder in their Coder workspace:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/TGoetzUTF/csc124-tools/main/submit.sh)
#
# It is safe to run as many times as you want.

set -u

# The class GitHub organization all submissions are created in.
ORG="CSC124-OL1A-FA26"

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
me=$(gh api user -q .login)
ok "Signed in to GitHub as: $me"

# ── 3. Which assignment is this? ─────────────────────────────────────
# The workspace template writes its name to ~/.csc124-assignment on startup,
# so we can detect the assignment automatically. Fall back to asking.
assignment=""
if [ -f "$HOME/.csc124-assignment" ]; then
  assignment=$(tr '[:upper:]' '[:lower:]' < "$HOME/.csc124-assignment" | sed 's/^csc124-//' | tr -cd 'a-z0-9-')
fi
if [ -z "$assignment" ] || [ "$assignment" = "csharp" ]; then
  read -rp "  Assignment name (e.g. week2): " raw
  assignment=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
fi
[ -n "$assignment" ] || fail "Assignment name is required (letters and numbers only, e.g. week2)."
ok "Assignment: $assignment"
# Repo lives in the class org, named so all of one week sorts together: csc124-week2-<you>
reponame="csc124-${assignment}-${me}"

# ── 3.5 Add the auto-run GitHub Action ───────────────────────────────
# Every push to GitHub will compile and run the student's code and show a
# green check (ran) or red X (didn't compile / crashed) on the commit.
# Written fresh every submit so the latest version always ships.
mkdir -p .github/workflows
cat > .github/workflows/run-code.yml <<'RUNYML'
name: Run My Code

on:
  push:
  workflow_dispatch:

jobs:
  run:
    runs-on: ubuntu-latest
    container: mcr.microsoft.com/dotnet/sdk:10.0
    timeout-minutes: 10
    steps:
      - name: Get the code
        uses: actions/checkout@v4

      - name: Compile and run the program
        run: |
          export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
          echo "## CSC 124 — Automated Run" >> "$GITHUB_STEP_SUMMARY"

          # Find a .csproj project, otherwise a single .cs file (.NET 10 file-based app)
          proj=$(find . -name '*.csproj' | head -1)
          if [ -n "$proj" ]; then
            target="--project $(dirname "$proj")"
          else
            csfile=$(find . -maxdepth 2 -name '*.cs' | head -1)
            [ -n "$csfile" ] || { echo "❌ No C# files found in this repository." | tee -a "$GITHUB_STEP_SUMMARY"; exit 1; }
            target="$csfile"
          fi
          echo "Running: \`dotnet run $target\`" >> "$GITHUB_STEP_SUMMARY"

          # Feed dummy input so programs that read input don't crash; cap at 60s.
          if timeout 60s bash -c "yes 0 | dotnet run $target" > output.txt 2>&1; then
            status="✅ Your program compiled and ran successfully."
            rc=0
          else
            rc=$?
            if [ "$rc" -eq 124 ]; then
              status="⚠️ Your program ran but did not finish within 60 seconds."
            else
              status="❌ Your program did not compile, or it crashed while running."
            fi
          fi

          echo "$status"
          {
            echo ""
            echo "$status"
            echo ""
            echo "<details><summary>Program output</summary>"
            echo ""
            echo '```'
            head -c 20000 output.txt
            echo '```'
            echo "</details>"
          } >> "$GITHUB_STEP_SUMMARY"

          # Red X only for a real compile error / crash; a timeout is a soft warning.
          [ "$rc" -eq 0 ] || [ "$rc" -eq 124 ]
RUNYML

# ── 4. Save your work as a commit ────────────────────────────────────
if [ ! -d .git ]; then
  git init -b main >/dev/null 2>&1 || git init >/dev/null
fi
git add -A
if git diff --cached --quiet 2>/dev/null && git rev-parse HEAD >/dev/null 2>&1; then
  ok "No new changes since your last submission — pushing what's here."
else
  git commit -m "Submission: $reponame ($(date '+%Y-%m-%d %H:%M'))" >/dev/null || fail "Nothing to commit. Are your files in this folder? (run: ls)"
  ok "Work saved as a commit."
fi

# ── 5. Create the repository in the class org (first time) or update it ─
# As org owner, your instructor already has access to every repo here —
# no collaborator invite needed.
if git remote get-url origin >/dev/null 2>&1; then
  git push -u origin HEAD >/dev/null 2>&1 || fail "Push failed. Ask your instructor for help and include this screen."
elif gh repo view "$ORG/$reponame" >/dev/null 2>&1; then
  git remote add origin "https://github.com/$ORG/$reponame.git"
  git push -u origin HEAD >/dev/null 2>&1 || fail "Push failed. Ask your instructor for help and include this screen."
else
  gh repo create "$ORG/$reponame" --private --source=. --push >/dev/null 2>&1 \
    || fail "Could not create the repository in $ORG. Make sure your instructor has added you to the organization, then try again."
fi
ok "Your code is on GitHub (private repository: $ORG/$reponame)."

# ── 6. Your submission link ──────────────────────────────────────────
say "DONE! Submit this link in Canvas:"
printf '\n  \033[1;33mhttps://github.com/%s/%s\033[0m\n\n' "$ORG" "$reponame"
