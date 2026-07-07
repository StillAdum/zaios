---
name: ZAIos Build Failure Auto-Healer
on:
  workflow_run:
    workflows: ["Build ZAIos ISO"] # Targets your main build file name
    types: [completed]

engine: copilot # Fast, large context window perfect for long compiler logs
permissions:
  contents: read
  pull-requests: read
  actions: read
---

# Intent
The purpose of this agentic workflow is to catch syntax, compilation, link-time, or packaging errors that occur during the 3+ hour ZAIos ISO building phase, automatically fix the codebase, and resubmit.

# Context
Only execute this script if the triggering workflow run conclusion was a 'failure'. If the build passed or was cancelled, exit immediately without spending tokens.

# Instructions
1. **Analyze Long Compiler Logs:** The ZAIos build contains deep C++/Qt6 compilation outputs. Fetch the failed job logs. If the log is cut short, look for the `build.log` or `build/**/*.log` artifacts uploaded by Step 21 of the failed run.
2. **Isolate Build Phases:** Identify which specific step failed (e.g., Kernel compilation, Qt6/Shell compilation, Rootfs assembly, or QEMU boot verification).
3. **Ignore Infrastructure / Disk Failures:** If the failure is due to a Runner timeout (exceeded 360 minutes) or out-of-disk-space error, do not modify code. Post a summary comment on the commit and exit.
4. **Fix Code Failures:** If the failure points to an absolute code bug (such as a broken `build.sh` regex path, missing dependency flag, or code syntax error in `src/`), modify the source files directly.
5. **Sandbox Validation:** Inside the secure sandbox environment, run syntax verification:
   `bash -n build.sh`
   Iterate up to 3 times if your proposed fix introduces a syntax error.
6. **Submit PR / Commit:** Commit the successful fix to a new branch named `ai-fix/zaios-<run_id>`. Automatically generate a Pull Request explaining what broke in the compiler logs and how the AI resolved it.
