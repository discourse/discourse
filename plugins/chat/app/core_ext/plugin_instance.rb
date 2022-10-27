# frozen_string_literal: true

DiscoursePluginRegistry.define_register(:chat_markdown_features, Set)

class Plugin::Instance
  def chat
    ChatPluginApiExtensions
  end

  module ChatPluginApiExtensions
    def self.enable_markdown_feature(name)
      DiscoursePluginRegistry.chat_markdown_features << name
    end
  end
end
