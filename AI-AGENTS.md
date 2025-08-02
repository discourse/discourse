# AI Coding Agent Guide

This file contains project-specific instructions that any AI coding agent should read at the start of each conversation and maintain in memory throughout the entire interaction. IMPORTANT: Once this file has been read or updated, it MUST be loaded at the beginning of any new conversation to ensure awareness of communication requirements, custom tasks, etc.

## Default Mode

- Architect mode should be enabled by default.
- Focus on providing detailed analysis, patterns, trade-offs, and architectural guidance.
- If you're unable to write code that fits these guidelines, stop and ask for additional context from the developer.

## Development Environment

Discourse is a large project with a long development history. Ensure you understand the context of any changes you're making before you start.

### General Rules
These rules apply to ALL files being changed.

- Always lint changed files.
- Always make display strings translatable.
- Avoid splitting display strings into pieces: use translation placeholders, or multiple translatable strings where appropriate.
- After completing a task, create a subagent to review the changes and ensure they conform to the instructions in this file, as well as the prompt(s) given.

### JavaScript
- Don't create empty backing classes for template tag only components, unless specifically asked to.
- Use the FormKit library for creating forms and form inputs. FormKit is documented here: https://meta.discourse.org/t/discourse-toolkit-to-render-forms/326439 and defined in `app/assets/javascripts/discourse/app/form-kit`

### JavaScript Documentation
- Always add JSDocs for classes, methods, and members, except for:
  - `@service` members
  - constructors
- Always use multiline JSDoc format.
- For components:
  - Specify the component name with `@component`.
  - List the params. These can be found in `this.args` in the JS, or `@paramname` in the `<template>`.
- For methods:
  - Don't add `@returns` for `@action` methods.
  - Don't add `@type` for getters, document with `@returns`.
- For members:
  - Specify the @type.

## Writing Tests

### General Rules
- Don't write tests for functionality that is handled by classes/components/modules other than the specific one being tested.
- Don't write obvious tests (eg, testing that a string can contain unicode characters)

### Ruby Test Rules
- Use `fab!()` instead of `let()` wherever possible.
- We use system tests in rails for UI integration testing, which is documented at https://dev.discourse.org/t/systematic-system-specs/82525, and examples are in `spec/system`
- We use page objects in system specs, defined in `spec/system/page_objects`

### Command Reference

#### Testing

```bash
# Run all Ruby tests
bin/rspec

# Run a specific Ruby test file
bin/rspec spec/path/to/file_spec.rb

# Run a specific Ruby test by line number
bin/rspec spec/path/to/file_spec.rb:123

# Run JavaScript tests
bin/rake qunit:test

# Run a specific JavaScript test module
pnpm ember exam --filter 'Module | Filter | goes-here'

```

#### Linting and Formatting

```bash
# Lint Ruby files
bundle exec rubocop path/to/file
bundle exec stree write Gemfile path/to/file

# Lint JavaScript/TypeScript files
pnpm lint:js path/to/file
pnpm lint:hbs path/to/file
pnpm lint:prettier path/to/file

# Lint CSS/SCSS files
pnpm lint:css path/to/file
```

## Site Settings
- Much of Discourse is configured by site settings. These are defined in `config/site_settings.yml` or `config/settings.yml` files.
- Site Setting functionality is defined in `lib/site_setting_extension.rb`
- Site settings are accessed with `SiteSetting.setting_name` in ruby and `siteSettings.setting_name` in JS, with the latter needing a `@service siteSettings` declaration in Ember components

## Service objects
- We have a service framework which is useful to extract business logic you usually find in controllers (validating parameters, fetching models, validating permissions, etc.). It’s not limited to controllers, though, and can be used anywhere.
- This is documented at https://meta.discourse.org/t/using-service-objects-in-discourse/333641
- Examples are found at `app/services` but ONLY for classes with include `Service::Base`

## Database & Performance

### ActiveRecord Best Practices
- Always use `includes()` or `preload()` to prevent N+1 queries when accessing associations
- Use `find_each()` or `in_batches()` for large dataset processing
- Prefer database-level operations (`update_all`, `delete_all`) over Ruby loops for bulk changes
- Use `exists?` instead of `present?` when checking for record existence

### Migration Guidelines
- Always include rollback logic in migrations
- Use `add_index(..., algorithm: :concurrently)` for large tables in production
- Never remove columns directly - deprecate first, then remove in subsequent release
- Test migrations on production-sized datasets when possible

### Query Optimization
- Use `explain` to analyze query performance during development
- Avoid `SELECT *` - specify needed columns explicitly
- Use database indexes strategically, but avoid over-indexing
- Consider using `counter_cache` for frequently accessed counts

## Security Guidelines

### XSS Prevention
- Always use `{{}}` (escaped) instead of `{{{ }}}` (unescaped) in Ember templates
- Sanitize user input using Discourse's built-in helpers (`sanitize`, `cook`)
- Never directly insert user content into `innerHTML` or similar DOM methods
- Use `@html` argument carefully and only with pre-sanitized content

- Always use Guardian classes for authorization checks, the Guardian class defined in lib/guardian.rb
- There are other Guardian classes defined in lib/guardian
- All state-changing requests must use POST/PUT/DELETE, never GET
- Ensure CSRF tokens are included in AJAX requests
- Use Rails' `protect_from_forgery` in controllers handling sensitive operations

### Input Sanitization
- Validate and sanitize all user inputs on both client and server side
- Use strong parameters in Rails controllers
- Apply appropriate length limits and format validation
- Never trust client-side validation alone

### Authorization
- Always use Guardian classes for authorization checks, the Guardian class defined in `lib/guardian.rb`
- There are other Guardian classes defined in `lib/guardian`
- Check permissions at both route and action levels
- Implement proper scope limiting (users should only see their own data)
- Use `can_see?` and `can_edit?` patterns consistently

## Knowledge Sharing and Persistence

- When asked to remember something, ALWAYS persist this information in a way that's accessible to ALL developers, not just in conversational memory
- Document important information in appropriate files (comments, documentation, README, etc.) so other developers (human or AI) can access it
- Information should be stored in a structured way that follows project conventions
- NEVER keep crucial information only in conversational memory - this creates knowledge silos
- If asked to implement something that won't be accessible to other users/developers in the repository, proactively highlight this issue
- The goal is complete knowledge sharing between ALL developers (human and AI) without exceptions
- When suggesting where to store information, recommend appropriate locations based on the type of information (code comments, documentation files, AI-AGENTS.md, etc.)
- Inform the developer when you detect a change in this file and have successfully reloaded it.
