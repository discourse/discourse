# frozen_string_literal: true

require "rails/generators/active_record/migration/migration_generator"

class Rails::PluginMigrationGenerator < ActiveRecord::Generators::MigrationGenerator
  class_option :plugin_name,
               type: :string,
               banner: "plugin_name",
               desc: "The plugin name to generate the migration into.",
               required: true

  source_root "#{Gem.loaded_specs["activerecord"].full_gem_path}/lib/rails/generators/active_record/migration/templates"

  private

  def db_migrate_path
    if options["plugin_name"]
      "plugins/#{options["plugin_name"]}/db/migrate"
    else
      "db/migrate"
    end
  end
end
