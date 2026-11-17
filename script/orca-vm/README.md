# Orca per-workspace Docker environment

The `docker` recipe in `orca.yaml` gives each Orca workspace its own Discourse dev container. Each container has its own Postgres and Redis, with `claude` and `codex` signed in. Orca connects to the container over SSH on a random localhost port.

## One-time setup

You need Docker (OrbStack or Docker Desktop) and Node on your PATH.

1. Build the base image. This clones Discourse, installs gems and packages, and migrates the databases:

   ```bash
   script/orca-vm/docker-base-image.sh
   ```

2. Start a sign-in container:

   ```bash
   script/orca-vm/docker-base-auth.sh start
   ```

3. In your own terminal, run the two sign-in commands that step 2 prints. Each one shows a URL to open in your browser.

4. Save the signed-in image:

   ```bash
   script/orca-vm/docker-base-auth.sh finish
   ```

Repeat steps 2 to 4 when an agent sign-in expires. Repeat all steps to pick up a new dev image or a large dependency change.

The signed-in image `discourse-orca-env:auth` holds your agent credentials. Keep it on your machine, and do not push it to a registry.

## Notes

- The containers have no Git credentials. Agents can fetch from GitHub, but cannot push.
- To check a workspace container, run `orca vm env doctor` in its terminal.
- `docker-state.json` holds the image names, the repo, and the checkout path. Override any value with an environment variable, for example `DISCOURSE_ORCA_REPO_REF=my-branch`.
- The SSH key is in `script/orca-vm/.ssh/`. It is ignored by Git.
