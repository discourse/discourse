require 'discourse_task/plugin'

module DiscourseTask
  class Engine < Rails::Engine

    engine_name 'discourse_task'

    initializer "discourse_task.configure_rails_initialization" do |app|

      app.config.after_initialize do
        DiscoursePluginRegistry.setup(DiscourseTask::Plugin)
      end

      app.config.to_prepare do
        DiscourseTask::Plugin.include_mixins
      end
    end

  end
end
