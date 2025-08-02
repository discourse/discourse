# frozen_string_literal: true

require "rails/generators/active_record/migration/migration_generator"

class Rails::PostMigrationGenerator < ActiveRecord::Generators::MigrationGenerator
  source_root "#{Gem.loaded_specs["activerecord"].full_gem_path}/lib/rails/generators/active_record/migration/templates"

  private

  def db_migrate_path
    Discourse::DB_POST_MIGRATE_PATH
  end
end
