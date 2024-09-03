---
title: How to run Discourse core, plugin and theme QUnit test suites
short_title: Run test suites
id: run-test-suites

---
Discourse has extensive frontend tests for core, plugins and themes. Once you have a functioning local development environment, those tests can be run locally in a number of different ways.

## Running tests in the browser

**Core / Plugins:** Visit `/tests` in your development environment

**Themes:** Visit `/theme-qunit` in your development (or production) environment, then choose the theme


In general, when working on core tests you should enable "Skip Plugins", and when you're working on plugins you should choose the specific plugin from the dropdown list (which will automatically 'Skip Core'). The core test suite is not expected to pass when plugins are enabled (because plugins often deliberately change core's behavior)

> :information_source: Unfortunately, at the time of writing, memory leaks in our tests mean that trying to running the entire suite in one browser tends to hit the browser memory limit. To run the entire suite across multiple browsers in parallel, check out the CLI examples below.

## Running tests on the CLI

### Core
Navigate to the root of the Ember application (`app/assets/javascripts/discourse`) in the Discourse repository and make sure you have run `pnpm install` since you last pulled in upstream changes.

From there, you can use standard Ember-CLI tooling to run the tests - check out the ["How to Run Tests" section of the Ember Guides](https://guides.emberjs.com/release/testing/#toc_how-to-run-tests). We also have [Ember Exam](https://ember-cli.github.io/ember-exam/) installed which provides some very useful randomization and parallelisation flags.


Here are some useful examples:
```bash
# Run entire core test suite across 5 'headless' instances of Chrome in parallel:
pnpm ember exam --parallel 5 --load-balance

# Run all tests which contain a certain string in their module/test name:
pnpm ember exam --filter "Integration | Component | bookmark"

# Run in "server" mode, which gives you a URL to load in a browser for easier debugging:
pnpm ember exam --filter "somefilter" --server
```

### Plugins
From the root directory of Discourse:
```bash
bin/rake "plugin:qunit" # Run all plugin qunit tests
bin/rake "plugin:qunit[discourse-chat-integration]" # Run a single plugin's qunit tests
```

### Themes
From the root directory of Discourse:
```bash
bin/rake "themes:qunit[url,<theme_url>]"
bin/rake "themes:qunit[name,<theme_name>]"
bin/rake "themes:qunit[id,<theme_id>]"
```
