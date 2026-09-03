# frozen_string_literal: true

module DiscourseWorkflows
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseWorkflows
    config.autoload_paths << File.join(config.root, "lib")
    initializer "discourse_workflows.plugin_autoloading", before: :setup_main_autoloader do
      Discourse.plugins.each do |plugin|
        %w[lib/discourse_workflows discourse_workflows].each do |relative_path|
          directory = File.join(plugin.directory, relative_path)
          if Dir.exist?(directory)
            Rails.autoloaders.main.push_dir(directory, namespace: DiscourseWorkflows)
          end
        end
      end
    end

    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare do
      Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) if Dir.exist?(scheduled_job_dir)
    end
  end
end
