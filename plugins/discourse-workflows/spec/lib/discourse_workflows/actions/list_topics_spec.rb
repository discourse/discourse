# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::ListTopics::V1 do
  fab!(:user)
  fab!(:category)
  fab!(:tag)
  fab!(:topic_1, :topic) do
    Fabricate(:topic, category: category, user: user, title: "First topic about workflows")
  end
  fab!(:post_1, :post) { Fabricate(:post, topic: topic_1, user: user) }
  fab!(:topic_2, :topic) do
    Fabricate(:topic, category: category, user: user, title: "Second topic about workflows")
  end
  fab!(:post_2, :post) { Fabricate(:post, topic: topic_2, user: user) }

  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:list_topics")
    end
  end

  describe "#execute" do
    it "returns topics matching the query" do
      action =
        described_class.new(
          configuration: {
            "query" => "category:#{category.slug}",
            "limit" => "10",
          },
        )
      context = {}
      input_items = [{ "json" => {} }]

      result = action.execute(context, input_items: input_items, node_context: {})

      expect(result.length).to eq(2)
      expect(result.map { |r| r["json"]["topic_id"] }).to contain_exactly(topic_1.id, topic_2.id)
    end

    it "respects the limit parameter" do
      action =
        described_class.new(
          configuration: {
            "query" => "category:#{category.slug}",
            "limit" => "1",
          },
        )
      context = {}
      input_items = [{ "json" => {} }]

      result = action.execute(context, input_items: input_items, node_context: {})

      expect(result.length).to eq(1)
    end

    it "defaults limit to 30 when not provided" do
      action = described_class.new(configuration: { "query" => "category:#{category.slug}" })
      context = {}
      input_items = [{ "json" => {} }]

      result = action.execute(context, input_items: input_items, node_context: {})

      expect(result.length).to eq(2)
    end

    it "returns expected fields for each topic" do
      SiteSetting.tagging_enabled = true
      topic_1.tags << tag

      action =
        described_class.new(
          configuration: {
            "query" => "category:#{category.slug}",
            "limit" => "10",
          },
        )
      context = {}
      input_items = [{ "json" => {} }]

      result = action.execute(context, input_items: input_items, node_context: {})

      topic_1_result = result.find { |r| r["json"]["topic_id"] == topic_1.id }["json"]
      expect(topic_1_result).to include(
        "topic_title" => topic_1.title,
        "category_id" => category.id,
        "username" => user.username,
        "status" => "open",
      )
      expect(topic_1_result["tags"]).to contain_exactly(tag.name)
      expect(topic_1_result["posts_count"]).to be_present
      expect(topic_1_result["views"]).to be_present
      expect(topic_1_result["like_count"]).to be_present
      expect(topic_1_result["created_at"]).to be_present
      expect(topic_1_result["bumped_at"]).to be_present
    end

    it "returns empty array when no topics match" do
      other_category = Fabricate(:category)
      action =
        described_class.new(
          configuration: {
            "query" => "category:#{other_category.slug}",
            "limit" => "10",
          },
        )
      context = {}
      input_items = [{ "json" => {} }]

      result = action.execute(context, input_items: input_items, node_context: {})

      expect(result).to eq([])
    end

    it "clamps limit to 100" do
      action =
        described_class.new(
          configuration: {
            "query" => "category:#{category.slug}",
            "limit" => "200",
          },
        )
      context = {}
      input_items = [{ "json" => {} }]

      result = action.execute(context, input_items: input_items, node_context: {})

      expect(result.length).to eq(2)
    end
  end
end
