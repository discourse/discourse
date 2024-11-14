---
title: Developing Discourse on GitHub Codespaces
short_title: GitHub Codespaces
id: github-codespaces

---

[GitHub Codespaces](https://github.com/features/codespaces) is a very fast way to get started with Discourse development. Their free tier is good for 30 hours per month of a 4-core machine.

# Getting Started

1. Navigate to [the github repository](https://github.com/discourse/discourse)

2. Press the <kbd>,</kbd> (comma) key on your keyboard, to open GitHub codespaces

3. Use 'change options' to customize the machine. Technically, the 2-core machine will work, but we recommend using at least 4-core for a better experience.

   ![Codespace config|1186x920,20%](/assets/codespaces-1.png)

4. Click "Create Codespace"

5. Wait for the container to download and start. When it's done, the README will appear, and you'll see the Discourse filesystem in the sidebar.

   ![Discourse in codespace editor|2286x1316,20%](/assets/codespaces-2.png)

6. Run the default build task using <kbd>Ctrl + Shift + B</kbd> (<kbd>Cmd + Shift + B</kbd> on mac).

   This will install dependencies, migrate the database, and start the server. It'll take a few minutes, especially on the lower-end machines. You'll see "Build successful" in the terminal when it's done.

7. Visit the "Ports" tab, and click the :globe_with_meridians: button for port 4200. This will open a new tab showing your development copy of Discourse

   ![Codespaces ports tab|1198x282,40%](/assets/codespaces-4.png)

8. All done! You can now make changes in the codespace and see them reflected in the preview.

   ![Discourse loaded in codespace environment|2110x1358,20%](/assets/codespaces-3.png)

The VSCode environment will automatically be configured with our recommended settings and extensions, including automatic linting and formatting.

To minimize usage, make sure to run "Codespaces: Stop Current Codespace" from the command palette (<kbd>Ctrl + Shift + P</kbd>  or <kbd>Cmd + Shift + P</kbd>) when you're finished. If you forget to do this, the Codespace *should* be shut down automatically after your account's configured idle time (default 30 mins). But, there are some situations where the codepace will not be detected as idle, so it's best to stop it deliberately.

# Tips

- You can launch a codespace from specific branches/PRs - just visit it, and press <kbd>,</kbd>

- You can manage all your codespaces at https://github.com/codespaces/

- Discourse's sample vscode `.vscode/settings.json` and `.vscode/tasks.json` will be copied when you first boot the codespace. From that point forward, if you want to use the latest sample config, you'll need to manually copy `.vscode/settings.json.sample` to `.vscode/settings.json`.
