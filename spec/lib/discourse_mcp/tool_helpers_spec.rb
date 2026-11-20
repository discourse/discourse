# frozen_string_literal: true

describe DiscourseMcp::ToolHelpers do
  describe ".topic_plugin_data" do
    it "adds namespaced plugin data to topic reads and filters using the current request context" do
      topic = Fabricate(:post).topic
      user = Fabricate(:user)
      context = Struct.new(:user, :guardian).new(user, Guardian.new(user))
      plugin = Plugin::Instance.new
      modifier =
        lambda do |data, topics, request_context|
          expect(topics).to eq([topic])
          expect(request_context).to eq(context)
          data.merge(topic.id => { "example" => { "visible" => true } })
        end
      plugin.register_modifier(:mcp_topic_plugin_data, &modifier)

      read =
        DiscourseMcp::Tools::GetTopic.call(
          arguments: {
            "topic_id" => topic.id,
          },
          request_context: context,
        ).fetch(:structuredContent)
      filtered =
        DiscourseMcp::Tools::FilterTopics
          .call(arguments: { "view" => "filtered", "filter" => "in:all" }, request_context: context)
          .fetch(:structuredContent)
          .fetch(:results)
          .first
      [read, filtered].each do |result|
        expect(result[:plugin_data]).to eq("example" => { "visible" => true })
      end
      expect(
        JSONSchemer.schema(DiscourseMcp::Tools::GetTopic::OUTPUT_SCHEMA).valid?(
          JSON.parse(JSON.generate(read)),
        ),
      ).to eq(true)
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, :mcp_topic_plugin_data, &modifier)
    end
  end
end
