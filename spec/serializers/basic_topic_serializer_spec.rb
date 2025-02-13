# frozen_string_literal: true

describe BasicTopicSerializer do
  fab!(:topic) { Fabricate(:topic, title: "Hur dur this is a title") }

  describe "#fancy_title" do
    it "returns the fancy title" do
      json = BasicTopicSerializer.new(topic).as_json

      expect(json[:basic_topic][:fancy_title]).to eq(topic.title)
    end

    it "returns the fancy title with a modifier" do
      plugin = Plugin::Instance.new
      modifier = :topic_serializer_fancy_title
      proc = Proc.new { "X" }
      DiscoursePluginRegistry.register_modifier(plugin, modifier, &proc)
      json = BasicTopicSerializer.new(topic).as_json

      expect(json[:basic_topic][:fancy_title]).to eq("X")
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &proc)
    end
  end
end
