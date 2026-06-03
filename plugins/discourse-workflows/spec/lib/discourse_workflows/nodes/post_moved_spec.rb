# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostMoved::V1 do
  fab!(:source_topic, :topic)
  fab!(:destination_category, :category)
  fab!(:destination_topic) { Fabricate(:topic, category: destination_category) }
  fab!(:tag) { Fabricate(:tag, name: "destination-tag") }
  fab!(:moved_post) { Fabricate(:post, topic: destination_topic, raw: "Moved reply") }
  fab!(:small_action) do
    Fabricate(:post, topic: destination_topic, post_type: Post.types[:small_action])
  end

  before do
    SiteSetting.tagging_enabled = true
    destination_topic.tags << tag
  end

  describe "#valid?" do
    it "returns true for regular posts with source and destination topics" do
      trigger = described_class.new(moved_post, source_topic.id)

      expect(trigger).to be_valid
    end

    it "returns false when post is nil" do
      trigger = described_class.new(nil, source_topic.id)

      expect(trigger).not_to be_valid
    end

    it "returns false when the original topic is missing" do
      trigger = described_class.new(moved_post, nil)

      expect(trigger).not_to be_valid
    end

    it "returns false for non-regular posts" do
      trigger = described_class.new(small_action, source_topic.id)

      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns moved post, destination topic, and original topic data" do
      trigger = described_class.new(moved_post, source_topic.id)
      output = trigger.output

      expect(output[:post]).to include(
        id: moved_post.id,
        raw: moved_post.raw,
        topic_id: destination_topic.id,
        category_id: destination_category.id,
        tags: ["destination-tag"],
      )
      expect(output[:topic]).to include(
        id: destination_topic.id,
        title: destination_topic.title,
        category_id: destination_category.id,
      )
      expect(output[:original_topic]).to include(id: source_topic.id, title: source_topic.title)
    end
  end

  describe "#matches?" do
    it "returns true when destination category and tags are blank" do
      trigger = described_class.new(moved_post, source_topic.id)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
    end

    it "returns true when the destination topic matches the configured category and tags" do
      trigger = described_class.new(moved_post, source_topic.id)

      expect(
        trigger.matches?(
          trigger_context("category_id" => destination_category.id.to_s, "tag_names" => [tag.name]),
        ),
      ).to eq(true)
    end

    it "returns false when the destination topic does not match category or tags" do
      other_category = Fabricate(:category)
      trigger = described_class.new(moved_post, source_topic.id)

      expect(trigger.matches?(trigger_context("category_id" => other_category.id.to_s))).to eq(
        false,
      )
      expect(trigger.matches?(trigger_context("tag_names" => ["missing"]))).to eq(false)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
