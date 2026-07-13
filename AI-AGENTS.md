# AI Coding Agent Guide

Project-specific instructions for AI agents. MUST be loaded at conversation start.

## Default Mode
- Architect mode enabled by default: detailed analysis, patterns, trade-offs, architectural guidance
- Stop and ask for context if unable to write code meeting guidelines

## Development Rules
Discourse is large with long history. Understand context before changes.

### Toolset
- Use `pnpm` for JavaScript, `bundle` for Ruby
- Use helpers in bin over bundle exec (bin/rspec, bin/rake, bin/lint)

### JavaScript and UI
- No empty backing classes for template-only components unless requested
- Use FormKit for forms, see ./docs/developer-guides/docs/03-code-internals/21-form-kit.md (`frontend/discourse/app/form-kit`)
- Use BEM for CSS, see ./docs/developer-guides/docs/03-code-internals/25-css-guidelines-bem.md
- Make display strings translatable (use placeholders, not split strings)
- Use "Sentence case" for strings, not "Proper Case" or "lower case"

### Comments & Types
- Only add comments to code when absolutely necessary. Self-documenting code is preferred
- In the frontend, typescript is typically used for platform-level code, javascript for business-logic
- Platform-level frontend code should include accurate types & tsdoc descriptions for public APIs
- Simple JSDoc comments can be used in other code for editor intellisense, but this is not essential

## Testing
- Use the skill at `.skills/discourse-writing-rspec-tests` when writing RSpec tests

## Commands

```bash
# JavaScript tests - bin/qunit
bin/qunit --help # detailed help
bin/qunit path/to/test-file.js  # Run all tests in file
bin/qunit path/to/tests/directory # Run all tests in directory

# Linting
bin/lint --fix path/to/file path/to/another/file
bin/lint --fix --recent # Lint all recently changed files
```

ALWAYS lint any changes you make with `bin/lint --fix`

## Site Settings
- Configured in `config/site_settings.yml` or `config/settings.yml` for plugins
- Functionality in `lib/site_setting_extension.rb`
- Access: `SiteSetting.setting_name` (Ruby), `siteSettings.setting_name` (JS with `@service siteSettings`)

## Services
- Extract business logic (validation, models, permissions) from controllers
- docs/developer-guides/docs/03-code-internals/19-service-objects.md
- Use the skill at .skills/discourse-service-authoring
- Examples: `app/services` (only classes with `Service::Base`)

## Database & Performance
- ActiveRecord: use `includes()`/`preload()` (N+1), `find_each()`/`in_batches()` (large sets), `update_all`/`delete_all` (bulk), `exists?` over `present?`
- Queries: use `explain`, specify columns, strategic indexing, `counter_cache` for counts

## Migrations
- Use the skill at `.skills/discourse-migration` before writing or reviewing any migration

## HTTP Response Codes
- **204 No Content**: Use `head :no_content` for successful operations that don't return data
  - DELETE operations that successfully remove a resource
  - UPDATE/PUT operations that succeed but don't need to return modified data
  - POST operations that perform an action without creating/returning resources (mark as read, clear notifications)
- **200 OK**: Use `render json: success_json` when returning confirmation data or when clients expect a response body
- **201 Created**: Use when creating resources, include location header or resource data
- **Do NOT use 204 when**:
  - Creating resources (use 201 with data)
  - Returning modified/useful data to the client
  - Clients expect confirmation data beyond success/failure

## Security
- XSS: use `{{}}` (escaped) not `{{{ }}}`, sanitize with `sanitize`/`cook`, no `innerHTML`, careful with `@html`
- Auth: Guardian classes (`lib/guardian.rb`), POST/PUT/DELETE for state changes, CSRF tokens, `protect_from_forgery`
- Input: validate client+server, strong parameters, length limits, don't trust client-only validation
- Authorization: Guardian classes, route+action permissions, scope limiting, `can_see?`/`can_edit?` patterns. Use user.guardian shorthand not Guardian.new(user)

## Knowledge Sharing
- ALWAYS persist information for ALL developers (no conversational-only memory)
- Follow project conventions, prevent knowledge silos
- Recommend storage locations by info type
- Inform when this file changes and reloads
