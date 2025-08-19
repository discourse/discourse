# frozen_string_literal: true

module ::DiscourseDataExplorer
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseDataExplorer
    config.autoload_paths << File.join(config.root, "lib")
    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare { Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) }
  end
end
