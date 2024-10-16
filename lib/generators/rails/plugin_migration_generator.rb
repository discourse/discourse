# frozen_string_literal: true

require "rails/generators/active_record/migration/migration_generator"

class Rails::PluginMigrationGenerator < ActiveRecord::Generators::MigrationGenerator
  source_root "#{Gem.loaded_specs["activerecord"].full_gem_path}/lib/rails/generators/active_record/migration/templates"
  class_option :plugin_name, type: :string, banner: "plugin name", required: true

  private

  def db_migrate_path
    "plugins/#{options["plugin_name"]}/db/migrate"
  end
end
