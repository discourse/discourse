# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostMoved::V1 do
  fab!(:source_topic, :topic)
  fab!(:destination_category, :category)
  fab!(:destination_topic) { Fabricate(:topic, category: destination_category) }
  fab!(:tag) { Fabricate(:tag, name: "destination-tag") }
  fab!(:moved_post) { Fabricate(:post, topic: destination_topic, raw: "Moved reply") }
  fab!(:original_post) { Fabricate(:post, topic: source_topic) }
  fab!(:moderator)
  fab!(:small_action) do
    Fabricate(:post, topic: destination_topic, post_type: Post.types[:small_action])
  end

  before do
    SiteSetting.tagging_enabled = true
    destination_topic.tags << tag
  end

  describe "#valid?" do
    it "returns true for regular posts with source and destination topics" do
      trigger = described_class.new(moved_post, source_topic.id, original_post)

      expect(trigger).to be_valid
    end

    it "returns false when post is nil" do
      trigger = described_class.new(nil, source_topic.id, original_post)

      expect(trigger).not_to be_valid
    end

    it "returns false when the original topic is missing" do
      trigger = described_class.new(moved_post, nil, original_post)

      expect(trigger).not_to be_valid
    end

    it "returns false for non-regular posts" do
      trigger = described_class.new(small_action, source_topic.id, original_post)

      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns moved post, destination topic, and original topic data", :aggregate_failures do
      trigger = described_class.new(moved_post, source_topic.id, original_post)
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
      expect(output[:actor]).to be_nil
      expect(output).to match_node_output_schema(described_class)
    end

    it "returns the user who moved the post as actor", :aggregate_failures do
      trigger =
        described_class.new(moved_post, source_topic.id, original_post, acting_user: moderator)

      expect(trigger.output[:actor]).to include(id: moderator.id, username: moderator.username)
      expect(trigger.output).to match_node_output_schema(described_class)
    end

    it "builds from the event PostMover fires" do
      post = Fabricate(:post, topic: source_topic)
      event =
        DiscourseEvent.track(:post_moved) do
          PostMover.new(source_topic, moderator, [post.id]).to_topic(destination_topic.id)
        end

      expect(described_class.new(*event[:params]).output[:actor]).to include(id: moderator.id)
    end
  end

  describe "#matches?" do
    it "returns true when destination category and tags are blank" do
      trigger = described_class.new(moved_post, source_topic.id, original_post)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
    end

    it "returns true when the destination topic matches the configured category and tags" do
      trigger = described_class.new(moved_post, source_topic.id, original_post)

      expect(
        trigger.matches?(
          trigger_context(
            "category_ids" => [destination_category.id.to_s],
            "tag_names" => [tag.name],
            "topic_ids" => [destination_topic.id],
          ),
        ),
      ).to eq(true)
    end

    it "matches any of the configured destination categories" do
      trigger = described_class.new(moved_post, source_topic.id, original_post)

      expect(
        trigger.matches?(
          trigger_context(
            "category_ids" => [Fabricate(:category).id.to_s, destination_category.id.to_s],
          ),
        ),
      ).to eq(true)
    end

    it "matches destination subcategories by default but not when excluded" do
      parent_category = Fabricate(:category)
      destination_category.update!(parent_category: parent_category)
      trigger = described_class.new(moved_post, source_topic.id, original_post)

      expect(trigger.matches?(trigger_context("category_ids" => [parent_category.id.to_s]))).to eq(
        true,
      )
      expect(
        trigger.matches?(
          trigger_context(
            "category_ids" => [parent_category.id.to_s],
            "include_subcategories" => false,
          ),
        ),
      ).to eq(false)
    end

    it "supports the legacy scalar category_id parameter" do
      trigger = described_class.new(moved_post, source_topic.id, original_post)

      expect(
        trigger.matches?(trigger_context("category_id" => destination_category.id.to_s)),
      ).to eq(true)
    end

    it "matches subcategories by default for legacy category_id-only nodes" do
      parent_category = Fabricate(:category)
      destination_category.update!(parent_category: parent_category)
      trigger = described_class.new(moved_post, source_topic.id, original_post)

      expect(trigger.matches?(trigger_context("category_id" => parent_category.id.to_s))).to eq(
        true,
      )
    end

    it "returns false when the destination topic does not match category, tags, or topics" do
      other_category = Fabricate(:category)
      trigger = described_class.new(moved_post, source_topic.id, original_post)

      expect(trigger.matches?(trigger_context("category_ids" => [other_category.id.to_s]))).to eq(
        false,
      )
      expect(trigger.matches?(trigger_context("tag_names" => ["missing"]))).to eq(false)
      expect(trigger.matches?(trigger_context("topic_ids" => [source_topic.id]))).to eq(false)
    end
  end
end
