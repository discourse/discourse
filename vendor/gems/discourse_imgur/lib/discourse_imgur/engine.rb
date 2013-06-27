require 'discourse_imgur/plugin'

module DiscourseImgur
  
  class Engine < Rails::Engine

    engine_name 'discourse_imgur'

    initializer "discourse_imgur.configure_rails_initialization" do |app|

      app.config.after_initialize do
        DiscoursePluginRegistry.setup(DiscourseImgur::Plugin)
      end

    end

  end

end
