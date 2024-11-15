---
title: Developing Discourse using a Dev Container
short_title: Dev Container
id: dev-container
---

[Dev Containers](https://containers.dev/) is an open standard for configuring a development environment inside a container. This almost entirely eliminates the need to install/configure Discourse-specific tools/dependencies on your local machine, and makes it very easy to keep up-to-date as Discourse evolves over time.

Dev Containers can be used in a number of different IDEs, or directly using their reference CLI. This guide will describe the setup process for VSCode.

## Getting started

1. [Download and install](https://code.visualstudio.com/) VSCode

1. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) in VSCode

1. Clone the Discourse repository onto your machine
   ```
   git clone https://github.com/discourse/discourse
   ```

1. In VSCode, use `File` -> `Open Folder`, then choose the Discourse directory

1. Open the folder in its Dev Container. This can be done via the popup prompt, or by opening the command palette (<kbd>Cmd/Ctrl + Shift + P</kbd>) and searching for "Open folder in container..."

1. If this is your first time launching a container, you will be prompted to install and start Docker Desktop. Once complete, go back to VSCode re-run "Open folder in container..."

1. Wait for the container to download and start. When it's done, the README will appear, and you'll see the Discourse filesystem in the sidebar.

1. Run the default build task using <kbd>Ctrl + Shift + B</kbd> (<kbd>Cmd + Shift + B</kbd> on mac).

   This will install dependencies, migrate the database, and start the server. It'll take a few minutes, especially on the lower-end machines. You'll see "Build successful" in the terminal when it's done.

1. Visit `http://localhost:4200` in your browser to see your new Discourse instance

1. All done! You can now make changes to Discourse's source code and see them reflected in the preview.

## Applying config/container updates

Every so often, the devcontainer config and the associated container image will be updated. VSCode should prompt you to "rebuild" to apply the changes. Alternatively, you can run "Dev Containers: Rebuild Container" from the VSCode command palette. The working directory, and your Redis/Postgres data will be preserved across rebuilds.

If you'd like to start from scratch with fresh database, you'll need to delete the `discourse-pg` and `discourse-redis` docker volumes. This can be done from the "Remote Explorer" tab of the VSCode sidebar.

Discourse's sample vscode `.vscode/settings.json` and `.vscode/tasks.json` will be copied when you first boot the codespace. From that point forward, if you want to use the latest sample config, you'll need to manually copy `.vscode/settings.json.sample` to `.vscode/settings.json`.

## References

- [Development container specification](https://containers.dev/)

- [VSCode devcontainer docs](https://code.visualstudio.com/docs/devcontainers/containers)
