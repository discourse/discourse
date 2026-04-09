# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::FetchTopic::V1 do
  fab!(:user)
  fab!(:category)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, category: category, user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "This is the topic body") }

  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:fetch_topic")
    end
  end

  def execute_node(configuration:, item:, run_as_user: Discourse.system_user)
    action = described_class.new(configuration: configuration)
    input_items = [item]
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => item.fetch("json") { {} } })
    exec_ctx =
      DiscourseWorkflows::NodeExecutionContext.new(
        input_items: input_items,
        run_as_user: run_as_user,
        resolver: resolver,
        configuration: configuration,
        configuration_schema: described_class.configuration_schema,
      )
    items = action.execute(exec_ctx)[0]
    items.first["json"]
  end

  describe "#execute" do
    it "returns all expected topic fields" do
      result =
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
          },
          item: {
            "json" => {
              "topic_id" => topic.id.to_s,
            },
          },
        )

      expect(result["topic"]["id"]).to eq(topic.id)
      expect(result["topic"]["title"]).to eq(topic.title)
      expect(result["topic"]["raw"]).to eq("This is the topic body")
      expect(result["topic"]["username"]).to eq(user.username)
      expect(result["topic"]["category_id"]).to eq(category.id)
      expect(result["topic"]["tags"]).to eq([])
    end

    it "returns tag names when topic has tags" do
      SiteSetting.tagging_enabled = true
      topic.tags << tag

      result =
        execute_node(
          configuration: {
            "topic_id" => topic.id.to_s,
          },
          item: {
            "json" => {
              "topic_id" => topic.id.to_s,
            },
          },
        )

      expect(result["topic"]["tags"]).to contain_exactly(tag.name)
    end

    it "raises when topic is not found" do
      expect do
        execute_node(configuration: { "topic_id" => "-1" }, item: { "json" => {} })
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
