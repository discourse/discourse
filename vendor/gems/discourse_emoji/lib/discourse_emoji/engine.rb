require 'discourse_emoji/plugin'

module DiscourseEmoji
  class Engine < Rails::Engine

    engine_name 'discourse_emoji'

    initializer "discourse_emoji.configure_rails_initialization" do |app|

      app.config.after_initialize do 
        DiscoursePluginRegistry.setup(DiscourseEmoji::Plugin)
      end
    end

  end
end