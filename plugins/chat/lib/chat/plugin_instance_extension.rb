# frozen_string_literal: true

module Chat
  module PluginInstanceExtension
    def self.prepended(base)
      DiscoursePluginRegistry.define_register(:chat_markdown_features, Set)
    end

    def chat
      ChatPluginApiExtensions
    end

    module ChatPluginApiExtensions
      def self.enable_markdown_feature(name)
        DiscoursePluginRegistry.chat_markdown_features << name
      end
    end
  end
end
