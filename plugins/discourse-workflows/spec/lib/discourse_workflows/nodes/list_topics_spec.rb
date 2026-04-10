# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ListTopics::V1 do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:tag)
  fab!(:topic_1, :topic) do
    Fabricate(:topic, category: category, user: user, title: "First topic about workflows")
  end
  fab!(:post_1) { Fabricate(:post, topic: topic_1, user: user) }
  fab!(:topic_2, :topic) do
    Fabricate(:topic, category: category, user: user, title: "Second topic about workflows")
  end
  fab!(:post_2) { Fabricate(:post, topic: topic_2, user: user) }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:list_topics")
    end
  end

  def execute_node(configuration:, run_as_user: nil)
    action = described_class.new(configuration: configuration)
    items = [{ "json" => {} }]
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} })
    kwargs = {
      input_items: items,
      resolver: resolver,
      configuration: configuration,
      configuration_schema: described_class.configuration_schema,
    }
    kwargs[:run_as_user] = run_as_user if run_as_user
    action.execute(DiscourseWorkflows::NodeExecutionContext.new(**kwargs))[0]
  end

  describe "#execute" do
    it "returns topics matching the query" do
      result =
        execute_node(configuration: { "query" => "category:#{category.slug}", "limit" => "10" })

      expect(result.length).to eq(2)
      expect(result.map { |r| r["json"]["topic"]["id"] }).to contain_exactly(topic_1.id, topic_2.id)
    end

    it "respects the limit parameter" do
      result =
        execute_node(configuration: { "query" => "category:#{category.slug}", "limit" => "1" })

      expect(result.length).to eq(1)
    end

    it "defaults limit to 30 when not provided" do
      result = execute_node(configuration: { "query" => "category:#{category.slug}" })

      expect(result.length).to eq(2)
    end

    it "returns expected fields for each topic" do
      SiteSetting.tagging_enabled = true
      topic_1.tags << tag

      result =
        execute_node(configuration: { "query" => "category:#{category.slug}", "limit" => "10" })

      topic_data = result.find { |r| r["json"]["topic"]["id"] == topic_1.id }.dig("json", "topic")
      expect(topic_data).to include(
        "title" => topic_1.title,
        "category_id" => category.id,
        "username" => user.username,
        "status" => "open",
      )
      expect(topic_data["tags"]).to contain_exactly(tag.name)
      expect(topic_data["posts_count"]).to be_present
      expect(topic_data["views"]).to be_present
      expect(topic_data["like_count"]).to be_present
      expect(topic_data["created_at"]).to be_present
      expect(topic_data["bumped_at"]).to be_present
    end

    it "returns empty array when no topics match" do
      result =
        execute_node(
          configuration: {
            "query" => "category:#{other_category.slug}",
            "limit" => "10",
          },
        )

      expect(result).to eq([])
    end

    it "clamps limit to 100" do
      result =
        execute_node(configuration: { "query" => "category:#{category.slug}", "limit" => "200" })

      expect(result.length).to eq(2)
    end

    it "defaults to system user for topic queries" do
      result = execute_node(configuration: { "query" => "category:#{category.slug}" })

      expect(result.length).to eq(2)
    end

    it "uses run_as_user when set" do
      result =
        execute_node(
          configuration: {
            "query" => "category:#{category.slug}",
          },
          run_as_user: other_user,
        )

      expect(result.length).to eq(2)
    end
  end
end
