---
title: Setup Continuous Integration using GitHub Actions
short_title: CI with GitHub Actions
id: ci-with-github-actions
---

## :mag: Overview

To build a robust extension for Discourse, it can be wise to include Continuous Integration (CI) into your plugin or theme-component. This will help to detect errors early on and lessen the chances of bugs in your code.

Setting up a <abbr title="Continuous Integration">CI</abbr> workflow using [GitHub Actions](https://github.com/features/actions) to automate builds and testing is an approach the Discourse team uses on all our components, and we recommend you do the same.

## :gear: Setting it up

To add automated workflows for GitHub actions to detect, you need to create a `.github/workflows` folder in the root directory of your repository.

Inside the `workflows` folder you can define a set of automations that GitHub actions will need to run. For instance, these could be `.yml` files for linting and tests.

We've created template workflows for both [plugins](https://github.com/discourse/discourse-plugin-skeleton) and [theme components](https://github.com/discourse/discourse-theme-skeleton) which you can make use of. These connect to our 'reusable workflow' definitions [here](https://github.com/discourse/.github/tree/main/.github/workflows).

In the template's skeleton repository, on GitHub you can click the <kbd>Use this template</kbd> button to create a plugin/theme component repository based on the template.

Alternatively, if you already have a project you'd like to add the workflows to, simply copy the relevant workflow into your repository's `.github/workflows/` folder:

**:electric_plug: Plugins:** [discourse-plugin.yml](https://github.com/discourse/discourse-plugin-skeleton/blob/main/.github/workflows/discourse-plugin.yml)

**:jigsaw: Themes and Theme Components:** [discourse-theme.yml](https://github.com/discourse/discourse-theme-skeleton/blob/main/.github/workflows/discourse-theme.yml)

> :point_up: These templates are locked to a specific major version of our reusable workflows. Small improvements we make to the workflows will automatically take effect in your theme/plugin. For breaking changes (e.g. introducing a new linter), we will bump the major version of the reusable workflows, and you will need to update your workflow to point to the new version

:tada: Voila! You're all setup! Simply, create a commit or a <abbr title="Pull Request">PR</abbr> to your repository and GitHub actions will auto-detect the workflows and begin running the jobs.

GitHub actions will show a breakdown of each test and after running it will indicate either a :white_check_mark: or :x: depending on if the test passed or failed.

If a test failed, clicking on the details will give you a some information on what failed which may give you clues on what's wrong with your code and what needs to be fixed.

[details="See example"]
![example failure|690x320](/assets/ci-with-github-actions-1.png)
[/details]

## :white_check_mark: Add your own tests

For plugin and components tests to work effectively, its important that you write tests for your plugin or theme component.

For details on how to write front-end tests with EmberJS see:

- https://meta.discourse.org/t/write-ember-acceptance-and-component-tests-for-discourse/49167
- https://guides.emberjs.com/v3.28.0/testing/

For more details on writing test RSpec tests with Rails see:

- [RSpec - Behavior Driven Development for Ruby](https://rspec.info/)

## :bulb: Examples

For your benefit, we've picked out a couple examples of plugins and theme components that have some robust testing integrated:

| Plugin / Component                                                               | Client Side Tests                                                                                 | Server Side Tests                                                                     |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| [Assign](https://meta.discourse.org/t/discourse-assign/58044)                    | [:link: View Folder](https://github.com/discourse/discourse-assign/tree/main/test/javascripts)    | [:link: View Folder](https://github.com/discourse/discourse-assign/tree/main/spec)    |
| [Calendar](https://meta.discourse.org/t/discourse-calendar/97376)                | [:link: View Folder](https://github.com/discourse/discourse-calendar/tree/main/test/javascripts)  | [:link: View Folder](https://github.com/discourse/discourse-calendar/tree/main/spec)  |
| [Reactions](https://meta.discourse.org/t/discourse-reactions/183261)             | [:link: View Folder](https://github.com/discourse/discourse-reactions/tree/main/test/javascripts) | [:link: View Folder](https://github.com/discourse/discourse-reactions/tree/main/spec) |
| [Right Sidebar Blocks](https://meta.discourse.org/t/right-sidebar-blocks/231067) | [:link: View Folder](https://github.com/discourse/discourse-right-sidebar-blocks/tree/main/test)  |
| [Tag Icons](https://meta.discourse.org/t/tag-icons/109757)                       | [:link: View Folder](https://github.com/discourse/discourse-tag-icons/tree/main/test)             |
| [Table Builder](https://meta.discourse.org/t/table-builder/236016)               | [:link: View Folder](https://github.com/discourse/discourse-table-builder/tree/main/test)         |
