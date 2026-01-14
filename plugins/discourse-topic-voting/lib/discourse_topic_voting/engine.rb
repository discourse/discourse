# frozen_string_literal: true

module DiscourseTopicVoting
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseTopicVoting
    config.autoload_paths << File.join(config.root, "lib")
  end
end
