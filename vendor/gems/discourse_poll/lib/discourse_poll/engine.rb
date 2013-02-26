require 'discourse_poll/plugin'

module DiscoursePoll
  class Engine < Rails::Engine

    engine_name 'discourse_poll'

    initializer "discourse_poll.configure_rails_initialization" do |app|

      app.config.after_initialize do
        DiscoursePluginRegistry.setup(DiscoursePoll::Plugin)
      end

      app.config.to_prepare do
        DiscoursePoll::Plugin.include_mixins
      end

    end

  end
end
