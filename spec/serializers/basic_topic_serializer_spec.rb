# frozen_string_literal: true

describe BasicTopicSerializer do
  fab!(:topic) { Fabricate(:topic, title: "Hur dur this is a title") }

  describe "#fancy_title" do
    it "returns the fancy title" do
      json = BasicTopicSerializer.new(topic).as_json

      expect(json[:basic_topic][:fancy_title]).to eq(topic.title)
    end

    it "returns the fancy title with a modifier" do
      DiscoursePluginRegistry.register_modifier(
        Plugin::Instance.new,
        :topic_serializer_fancy_title,
      ) { "X" }
      json = BasicTopicSerializer.new(topic).as_json

      expect(json[:basic_topic][:fancy_title]).to eq("X")
    end
  end
end
