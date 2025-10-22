# Discourse Github

https://meta.discourse.org/t/discourse-github/99895/

This plugin combines functionality of deprecated github_badges and discourse-github-linkback plugins.

### Installation

Follow the [plugin installation guide](https://meta.discourse.org/t/install-a-plugin/19157).

### Github Badges

Assign badges to your users based on GitHub contributions.

#### How to use:

1. Enable `github badges enabled` in Settings -> Plugins.

2. Generate an access token on Github. Be sure to give it only the `public_repo` scope. Paste that token into the `github linkback access token` setting.

3. Add URL of the GitHub repo to scan for contributions to the `github badges repo` site setting.

### Github Linkback

Create a link from a Github pull request or commit back to a Discourse post where it is mentioned.

#### How to use:

1. Enable `github linkback enabled` in Settings -> Plugins.

2. Generate an [access token](https://github.com/settings/tokens) on Github.
   Be sure to give it <em>only</em> the `public_repo` scope. Paste that token into the
   `github linkback access token` setting.

3. Finally, add the projects you wish to post to in the `github linkback projects` site setting in the formats:
   - `username/repository` for specific repositories
   - `username/*` for all repositories of a certain user

### Github Permalink

Replace Github non-permalinks with [permalinks](https://help.github.com/articles/getting-permanent-links-to-files/).

#### How to use:

1. Enable `github permalinks enabled` in Settings -> Plugins.
2. If you want to exclude certain files or directories from permalink overwrites, you can modify that in the `github permalinks exclude` site setting in the following formats:
   - `filename` links to all files with matching filename
   - `username/*` links to all repositories belonging to the user/organization
   - `username/repository/*` links to any file in the repository
   - `username/repository/directory/*` links to any file in the directory within repository
   - `username/repository/file.rb` a specific file
