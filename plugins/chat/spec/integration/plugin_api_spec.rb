# frozen_string_literal: true

describe "Plugin API for chat" do
  before { SiteSetting.chat_enabled = true }

  let(:metadata) do
    metadata = Plugin::Metadata.new
    metadata.name = "test"
    metadata
  end

  let(:plugin_instance) do
    plugin = Plugin::Instance.new(nil, "/tmp/test.rb")
    plugin.metadata = metadata
    plugin
  end

  describe "chat.enable_markdown_feature" do
    it "stores the markdown feature" do
      plugin_instance.chat.enable_markdown_feature(:foo)

      expect(DiscoursePluginRegistry.chat_markdown_features.include?(:foo)).to be_truthy
    end
  end
end
