# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Discourse is a modern forum software application built using:
- **Backend**: Ruby on Rails - Handles the API layer responding to requests RESTfully in JSON
- **Frontend**: Ember.js - Provides the client-side application
- **Database**: PostgreSQL - Main data store
- **Caching**: Redis - Used for caching and transient data

## Common Development Commands

### Building and Running the Application

```bash
# Start both Rails and Ember development servers
pnpm dev

# Start Rails server only
bin/rails server

# Start Ember CLI server only
bin/ember-cli server

# Start with Unicorn server instead of Puma
bin/unicorn
```

### Testing

#### Ruby/Rails Tests

```bash
# Run all RSpec tests
bin/rspec

# Run specific tests
bin/rspec path/to/spec_file.rb

# Run tests in parallel (TurboTests)
bin/turbo_rspec

# Run system tests
bin/system_rspec

# Run plugin tests
LOAD_PLUGINS=1 bin/rspec plugins/[plugin_name]/spec
```

#### JavaScript Tests

```bash
# Run all QUnit tests
bin/rake qunit:test

# Run specific QUnit tests
bin/rake "qunit:test[module_name]"

# Run tests via Ember CLI
bin/ember-cli --test

# Run with specific seed
QUNIT_SEED=1234 bin/rake qunit:test
```

### Linting and Code Quality

```bash
# Run all linters
pnpm lint

# Fix linting issues automatically
pnpm lint:fix

# Ruby linting
bin/rubocop
bin/rubocop -a  # Auto-fix issues

# JavaScript linting
pnpm lint:js
pnpm lint:js:fix

# Template linting
pnpm lint:hbs
pnpm lint:hbs:fix

# CSS linting
pnpm lint:css
pnpm lint:css:fix

# Prettier formatting
pnpm lint:prettier
pnpm lint:prettier:fix
```

### Database Management

```bash
# Run database migrations
bin/rake db:migrate

# Reset and seed development database
bin/rake dev:reset

# Seed the database
bin/rake db:seed
```

### Asset Management

```bash
# Precompile assets for production
bin/rake assets:precompile

# Update JavaScript dependencies
bin/rake javascript:update
```

## Architecture Overview

### Directory Structure

- **app/**: Core application code
  - **models/**: Database models (User, Topic, Post, etc.)
  - **controllers/**: Request handling logic
  - **serializers/**: JSON API serializers
  - **assets/javascripts/discourse/**: Ember.js frontend application
  - **jobs/**: Background job definitions
  - **services/**: Service objects and business logic

- **config/**: Application configuration
  - **initializers/**: Setup code that runs on application startup
  - **routes.rb**: Defines API endpoints and URL structure
  - **site_settings.yml**: System-wide settings

- **lib/**: Core functionality libraries
  - **plugin/**: Plugin system infrastructure
  - **guardian/**: Permission system
  - **tasks/**: Rake tasks

- **plugins/**: Plugin directories for extending Discourse

### Key Components

1. **API Architecture**
   - The backend is a RESTful JSON API
   - Controllers return serialized JSON data
   - Frontend consumes this API via Ember.js

2. **Plugin System**
   - Plugins can extend almost any part of Discourse
   - Each plugin has its own MVC structure
   - Plugins register with `lib/plugin/instance.rb`

3. **Site Settings**
   - Configuration via site settings in `config/site_settings.yml`
   - Allows runtime configuration changes without code modification

4. **Guardian System**
   - Permission system controls access to resources
   - Guards against unauthorized actions

5. **Background Jobs**
   - Uses Sidekiq for asynchronous processing
   - Jobs defined in `app/jobs/`

6. **Frontend Architecture**
   - Ember.js application follows component-based architecture
   - Uses Ember CLI for asset building
   - Communicates with backend via JSON API

## Development Workflow

1. Start development servers with `pnpm dev`
2. Make code changes
3. Run appropriate tests (`bin/rspec` or `bin/rake qunit:test`)
4. Lint code (`pnpm lint` or specific linters)
5. Reset development data if needed (`bin/rake dev:reset`)

## Docker Development Environment

For Docker-based development:

```bash
# Start the dev environment
bin/docker/boot_dev --init

# Rails console
bin/docker/rails c

# Run rake tasks
bin/docker/rake [task_name]

# Run RSpec tests
bin/docker/rspec

# Reset database
bin/docker/reset_db

# Shell access
bin/docker/shell

# Shutdown dev environment
bin/docker/shutdown_dev
```

Access the application:
- Web UI: http://localhost:4200 (Ember server)
- Alternative: http://localhost:9292 (Unicorn server)
- MailHog (for email testing): http://localhost:8025

## Plugin Development

### Plugin Structure

When developing plugins for Discourse, follow this structure:

```
plugins/my-plugin/
├── app/
│   ├── controllers/
│   ├── models/
│   └── serializers/
├── assets/
│   ├── javascripts/
│   └── stylesheets/
├── config/
│   ├── locales/
│   ├── routes.rb
│   └── settings.yml
├── db/
│   └── migrate/
├── lib/
│   └── my_plugin/
├── plugin.rb
└── README.md
```

### Common Issues and Solutions

1. **NameError: uninitialized constant**
   - Keep constraint classes at the module level, not nested inside other classes
   - Use the proper namespace for your plugin classes
   - Example: `module ::MyPlugin` instead of `module MyPlugin`

2. **Model Loading**
   - Make sure models are explicitly loaded in the plugin.rb file
   - Include `require_relative "app/models/your_model"` in the after_initialize block

3. **Route Constraints**
   - Define constraint classes separately from Engine classes
   - Example:
   ```ruby
   module ::MyPlugin
     class CustomConstraint
       def matches?(request)
         # constraint logic
       end
     end
     
     class Engine < ::Rails::Engine
       # engine configuration
     end
   end
   ```

4. **Plugin Routes**
   - Mount your plugin's engine in the Rails app:
   ```ruby
   Discourse::Application.routes.draw { mount ::MyPlugin::Engine, at: "/" }
   ```
   - Define your plugin's routes in config/routes.rb

5. **Asset Registration**
   - Use `register_asset` in plugin.rb for stylesheets
   - For admin routes, use `add_admin_route "translation_key", "route-name"`