#!/usr/bin/env rake
# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Discourse::Application.load_tasks

# this prevents crashes when migrating a database in production in certain
# PostgreSQL configuations when trying to create structure.sql
Rake::Task["db:structure:dump"].clear if Rails.env.production?
