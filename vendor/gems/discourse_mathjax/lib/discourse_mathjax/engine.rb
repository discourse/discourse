require 'discourse_mathjax/plugin'

module DiscourseMathjax
  class Engine < Rails::Engine

    engine_name 'discourse_mathjax'

    initializer "discourse_mathjax.configure_rails_initialization" do |app|

      app.config.after_initialize do
        DiscoursePluginRegistry.setup(DiscourseMathjax::Plugin)
        Post.white_listed_image_classes << "mathjax"
      end
    end

  end
end
