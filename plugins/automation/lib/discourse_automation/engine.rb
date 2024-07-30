# frozen_string_literal: true

module ::DiscourseAutomation
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseAutomation
    config.autoload_paths << File.join(config.root, "lib")
    scheduled_job_dir = "#{config.root}/app/jobs/scheduled"
    config.to_prepare do
      Rails.autoloaders.main.eager_load_dir(scheduled_job_dir) if Dir.exist?(scheduled_job_dir)
    end
  end

  def self.filter_by_trigger(items, trigger)
    trigger = trigger&.to_sym

    indexed_items =
      items.each_with_object({}) do |item, acc|
        if item[:triggerable] == trigger || item[:triggerable].nil?
          acc[item[:name]] = item if acc[item[:name]].nil? || item[:triggerable] == trigger
        end
      end

    indexed_items.values
  end
end
