# AI Coding Agent Guide

Project-specific instructions for AI agents. MUST be loaded at conversation start.

## Default Mode
- Architect mode enabled by default: detailed analysis, patterns, trade-offs, architectural guidance
- Stop and ask for context if unable to write code meeting guidelines

## Development Rules
Discourse is large with long history. Understand context before changes.

### All Files
- Always lint changed files
- Make display strings translatable (use placeholders, not split strings)
- Create subagent to review changes against this file after completing tasks

### Toolset
- Use `pnpm` for JavaScript, `bundle` for Ruby
- Use helpers in bin over bundle exec (bin/rspec, bin/rake)

### JavaScript
- No empty backing classes for template-only components unless requested
- Use FormKit for forms: https://meta.discourse.org/t/discourse-toolkit-to-render-forms/326439 (`app/assets/javascripts/discourse/app/form-kit`)

### JSDoc
- Required for classes, methods, members (except `@service` members, constructors)
- Multiline format only
- Components: `@component` name, list params (`this.args` or `@paramname`)
- Methods: no `@returns` for `@action`, use `@returns` for getters (not `@type`)
- Members: specify `@type`

## Testing
- Do not write unnecessary comments in tests, every single assertion doesn't need a comment
- Don't test functionality handled by other classes/components
- Don't write obvious tests
- Ruby: use `fab!()` over `let()`, system tests for UI (`spec/system`), use page objects for system spec finders (`spec/system/page_objects`)

### Commands
```bash
# Ruby tests
bin/rspec [spec/path/file_spec.rb[:123]]
LOAD_PLUGINS=1 bin/rspec  # Plugin tests

# JavaScript tests
bin/rake qunit:test # RUN all non plugin tests
LOAD_PLUGINS=1 TARGET=all FILTER='fill filter here' bin/rake qunit:test # RUN specific tests based on filter

Exmaple filters JavaScript tests:

  emoji-test.js
    ...
    acceptance("Emoji" ..
      test("cooked correctly")
    ...
  Filter string is: "Acceptance: Emoji: cooked correctly"

  user-test.js
    ...
    module("Unit | Model | user" ..
      test("staff")
    ...
  Filter string is: "Unit | Model | user: staff"

# Linting
bin/lint path/to/file path/to/another/file
bin/lint --fix path/to/file path/to/another/file
bin/lint --fix --recent # Lint all recently changed files
```

ALWAYS lint any changes you make

## Site Settings
- Configured in `config/site_settings.yml` or `config/settings.yml` for plugins
- Functionality in `lib/site_setting_extension.rb`
- Access: `SiteSetting.setting_name` (Ruby), `siteSettings.setting_name` (JS with `@service siteSettings`)

## Services
- Extract business logic (validation, models, permissions) from controllers
- https://meta.discourse.org/t/using-service-objects-in-discourse/333641
- Examples: `app/services` (only classes with `Service::Base`)

## Database & Performance
- ActiveRecord: use `includes()`/`preload()` (N+1), `find_each()`/`in_batches()` (large sets), `update_all`/`delete_all` (bulk), `exists?` over `present?`
- Migrations: rollback logic, `algorithm: :concurrently` for large tables, deprecate before removing columns
- Queries: use `explain`, specify columns, strategic indexing, `counter_cache` for counts

## Security
- XSS: use `{{}}` (escaped) not `{{{ }}}`, sanitize with `sanitize`/`cook`, no `innerHTML`, careful with `@html`
- Auth: Guardian classes (`lib/guardian.rb`), POST/PUT/DELETE for state changes, CSRF tokens, `protect_from_forgery`
- Input: validate client+server, strong parameters, length limits, don't trust client-only validation
- Authorization: Guardian classes, route+action permissions, scope limiting, `can_see?`/`can_edit?` patterns

## Knowledge Sharing
- ALWAYS persist information for ALL developers (no conversational-only memory)
- Follow project conventions, prevent knowledge silos
- Recommend storage locations by info type
- Inform when this file changes and reloads
