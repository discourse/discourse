# frozen_string_literal: true

module Chat
  module PluginInstanceExtension
    class << self
      def prepended(base)
        DiscoursePluginRegistry.define_register(:chat_markdown_features, Set)
      end
    end

    def chat
      ChatPluginApiExtensions
    end

    module ChatPluginApiExtensions
      class << self
        def enable_markdown_feature(name)
          DiscoursePluginRegistry.chat_markdown_features << name
        end
      end
    end
  end
end
