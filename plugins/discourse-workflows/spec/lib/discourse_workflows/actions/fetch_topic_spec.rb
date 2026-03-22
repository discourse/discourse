# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::FetchTopic do
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

  describe "#execute_single" do
    it "returns all expected topic fields" do
      action = described_class.new(configuration: {})
      context = { "trigger" => { "topic_id" => topic.id.to_s } }
      item = { "json" => { "topic_id" => topic.id.to_s } }
      config = { "topic_id" => topic.id.to_s }

      result = action.execute_single(context, item: item, config: config)

      expect(result[:topic_id]).to eq(topic.id)
      expect(result[:topic_title]).to eq(topic.title)
      expect(result[:topic_raw]).to eq("This is the topic body")
      expect(result[:username]).to eq(user.username)
      expect(result[:category_id]).to eq(category.id)
      expect(result[:tags]).to eq([])
    end

    it "returns tag names when topic has tags" do
      SiteSetting.tagging_enabled = true
      topic.tags << tag

      action = described_class.new(configuration: {})
      item = { "json" => { "topic_id" => topic.id.to_s } }
      config = { "topic_id" => topic.id.to_s }

      result = action.execute_single({}, item: item, config: config)

      expect(result[:tags]).to contain_exactly(tag.name)
    end

    it "raises when topic is not found" do
      action = described_class.new(configuration: {})
      item = { "json" => {} }
      config = { "topic_id" => "-1" }

      expect { action.execute_single({}, item: item, config: config) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end
  end
end
