# frozen_string_literal: true

module ::DiscourseRewind
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseRewind
    config.autoload_paths << File.join(config.root, "lib")
    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare do
      Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) if Dir.exist?(scheduled_job_dir)
    end

    Rails.application.reloader.to_prepare do
      Dir[
        "#{Rails.root}/plugins/discourse-rewind/app/services/discourse_rewind/rewind/action/*.rb"
      ].each { |file| require_dependency file }
    end
  end
end
