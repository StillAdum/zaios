---
name: ZAIos Build Failure Auto-Healer
on:
  workflow_run:
    workflows: ["Build ZAIos ISO"]
    types: [completed]
    branches:
      - main
      - master

engine: copilot
permissions:
  contents: read
  pull-requests: read
  actions: read

safe-outputs:
  create-pull-request:
    branch-prefix: "ai-fix/zaios-"
    allowed-files:
      - "src/**"
      - "build.sh"
      - "scripts/**"
	  - "rootfs/**"
	  - "calamares/**"
---

# Intent
The purpose of this agentic workflow is to catch compilation errors during the ZAIos ISO building phase, automatically fix the codebase, and resubmit.

# Context
Only execute this script if the triggering workflow run conclusion was a 'failure'.

# Instructions
1. Analyze the failed job logs from the triggering run.
2. Identify which specific step failed (e.g., Kernel compilation, Qt6/Shell compilation).
3. Ignore infrastructure timeouts or disk space exhaustion.
4. Modify code or build scripts directly to fix absolute software bugs.
5. Run validation inside the sandbox container: bash -n build.sh || bash -n scripts/build.sh
6. Commit the successful fix to a new branch using your create-pull-request capability.