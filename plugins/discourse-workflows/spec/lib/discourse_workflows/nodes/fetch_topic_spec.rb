# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::FetchTopic::V1 do
  fab!(:user)
  fab!(:category)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, category: category, user: user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user, raw: "This is the topic body") }

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
