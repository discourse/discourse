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

From the root directory of Discourse, use `bin/qunit` (make sure you have run `pnpm install` since you last pulled in upstream changes). It wraps [Ember Exam](https://ember-cli.github.io/ember-exam/) for randomization and parallelisation, and by default runs against the running Rails server and existing JS assets. Run `bin/qunit --help` for the full list of options.

Here are some useful examples:

```sh
# Run a single test file, or every test in a directory:
bin/qunit frontend/discourse/tests/integration/components/bookmark-test.gjs
bin/qunit frontend/discourse/tests/integration/components

# Run the entire core suite across 5 headless Chrome instances in parallel:
bin/qunit --parallel 5

# Run all tests whose "module: test name" contains a literal substring (case-insensitive):
bin/qunit --filter "Integration | Component | bookmark"

# Use a JavaScript regular expression instead, e.g. for alternation:
bin/qunit --filter-regex "bookmark|reaction"

# Spin up an isolated server and run in a visible browser for easier debugging:
bin/qunit --standalone --no-headless
```

> :information_source: `--filter` matches a literal substring, so `|` and other regex metacharacters are treated literally. Use `--filter-regex` when you need alternation or other patterns.

### Plugins

From the root directory of Discourse:

```sh
bin/rake "plugin:qunit" # Run all plugin qunit tests
bin/rake "plugin:qunit[discourse-chat-integration]" # Run a single plugin's qunit tests
```

### Themes

From the root directory of Discourse:

```sh
bin/rake "themes:qunit[url,<theme_url>]"
bin/rake "themes:qunit[name,<theme_name>]"
bin/rake "themes:qunit[id,<theme_id>]"
```
