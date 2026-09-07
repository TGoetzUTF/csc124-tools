# CSC 124 Tools

Helper scripts for CSC 124 (Principles of Computer Science) at Toccoa Falls College.

## Submitting an assignment

In your class Coder workspace, open the Terminal in your assignment folder and type:

```bash
submit
```

Answer the questions it asks (a one-time GitHub browser sign-in the first time, and the assignment name). It creates your private GitHub repository, uploads your code, gives your instructor access, and prints the link to submit in Canvas. Run it again any time you change your code — the link stays the same.

If `submit` says "command not found" (older workspace), restart your workspace from the Coder dashboard, or run the full version:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/TGoetzUTF/csc124-tools/main/submit.sh)
```
