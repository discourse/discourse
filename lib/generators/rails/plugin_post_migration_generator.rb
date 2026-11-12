# frozen_string_literal: true

require "rails/generators/active_record/migration/migration_generator"

class Rails::PluginPostMigrationGenerator < ActiveRecord::Generators::MigrationGenerator
  class_option :plugin_name,
               type: :string,
               banner: "plugin_name",
               desc: "The plugin name to generate the post migration into.",
               required: true

  source_root "#{Gem.loaded_specs["activerecord"].full_gem_path}/lib/rails/generators/active_record/migration/templates"

  private

  def db_migrate_path
    "plugins/#{options["plugin_name"]}/#{Discourse::DB_POST_MIGRATE_PATH}"
  end
end
