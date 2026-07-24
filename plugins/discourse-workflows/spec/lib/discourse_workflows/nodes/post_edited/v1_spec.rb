# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostEdited::V1 do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:reply_user, :user)
  fab!(:parent_category, :category)
  fab!(:category) { Fabricate(:category, parent_category: parent_category) }
  fab!(:first_post) { create_post(user: user, category: category, raw: "First post") }
  fab!(:topic) { first_post.topic }
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }
  fab!(:reply) { create_post(user: reply_user, topic: topic, raw: "Reply") }
  fab!(:small_action) do
    Fabricate(:post, topic: topic, user: reply_user, post_type: Post.types[:small_action])
  end

  before do
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe "#valid?" do
    it "returns true for regular posts" do
      trigger = described_class.new(first_post, "<p>Cooked</p>")

      expect(trigger).to be_valid

      reply_trigger = described_class.new(reply, "<p>Cooked</p>")
      expect(reply_trigger).to be_valid
    end

    it "returns false for non-regular posts" do
      trigger = described_class.new(small_action, "<p>Cooked</p>")

      expect(trigger).not_to be_valid
    end

    it "returns false when workflow execution requested the edit to be skipped" do
      revisor = instance_double(PostRevisor, opts: { skip_workflows: true })
      trigger = described_class.new(first_post, false, revisor)

      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns post and topic data" do
      trigger = described_class.new(first_post, "<p>Cooked</p>")
      output = trigger.output

      expect(output[:post][:id]).to eq(first_post.id)
      expect(output[:post][:raw]).to eq(first_post.raw)
      expect(output[:post][:cooked]).to eq("<p>Cooked</p>")
      expect(output[:user]).to include(
        id: user.id,
        username: user.username,
        trust_level: user.trust_level,
        trust_level_name: TrustLevel.name(user.trust_level),
      )
      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:topic][:tags].map { |topic_tag| topic_tag[:name] }).to eq(["test-tag"])
      expect(output).not_to have_key(:cooked)
    end
  end

  describe "#matches?" do
    it "returns true when category, tags, and trust levels are blank" do
      trigger = described_class.new(first_post, "<p>Cooked</p>")

      expect(trigger.matches?(trigger_context({}))).to eq(true)
    end

    it "defaults to first posts only" do
      trigger = described_class.new(reply, "<p>Cooked</p>")

      expect(trigger.matches?(trigger_context({}))).to eq(false)
    end

    it "matches replies when configured for all posts" do
      trigger = described_class.new(reply, "<p>Cooked</p>")

      expect(trigger.matches?(trigger_context("post_scope" => "all_posts"))).to eq(true)
    end

    it "matches only replies when configured for replies" do
      first_post_trigger = described_class.new(first_post, "<p>Cooked</p>")
      reply_trigger = described_class.new(reply, "<p>Cooked</p>")

      expect(first_post_trigger.matches?(trigger_context("post_scope" => "replies"))).to eq(false)
      expect(reply_trigger.matches?(trigger_context("post_scope" => "replies"))).to eq(true)
    end

    it "matches the configured category including subcategories by default" do
      trigger = described_class.new(first_post, "<p>Cooked</p>")

      expect(trigger.matches?(trigger_context("category_ids" => [parent_category.id.to_s]))).to eq(
        true,
      )
      expect(trigger.matches?(trigger_context("category_ids" => [category.id.to_s]))).to eq(true)
    end

    it "does not match parent-category selections when subcategories are excluded" do
      trigger = described_class.new(first_post, "<p>Cooked</p>")

      expect(
        trigger.matches?(
          trigger_context(
            "category_ids" => [parent_category.id.to_s],
            "include_subcategories" => false,
          ),
        ),
      ).to eq(false)
      expect(
        trigger.matches?(
          trigger_context("category_ids" => [category.id.to_s], "include_subcategories" => false),
        ),
      ).to eq(true)
    end

    it "matches any of the configured categories" do
      trigger = described_class.new(first_post, "<p>Cooked</p>")

      expect(
        trigger.matches?(
          trigger_context("category_ids" => [Fabricate(:category).id.to_s, category.id.to_s]),
        ),
      ).to eq(true)
    end

    it "supports the legacy scalar category_id parameter" do
      trigger = described_class.new(first_post, "<p>Cooked</p>")

      expect(trigger.matches?(trigger_context("category_id" => category.id.to_s))).to eq(true)
    end

    it "matches the configured tags and trust levels" do
      trigger = described_class.new(first_post, "<p>Cooked</p>")

      expect(
        trigger.matches?(trigger_context("tag_names" => [tag.name], "trust_levels" => ["2"])),
      ).to eq(true)
    end

    it "returns false when category, tags, or trust levels do not match" do
      other_category = Fabricate(:category)
      trigger = described_class.new(first_post, "<p>Cooked</p>")

      expect(trigger.matches?(trigger_context("category_ids" => [other_category.id.to_s]))).to eq(
        false,
      )
      expect(trigger.matches?(trigger_context("tag_names" => ["missing"]))).to eq(false)
      expect(trigger.matches?(trigger_context("trust_levels" => ["1"]))).to eq(false)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
