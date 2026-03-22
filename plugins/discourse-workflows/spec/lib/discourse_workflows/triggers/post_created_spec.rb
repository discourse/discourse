# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Triggers::PostCreated do
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:reply_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }
  fab!(:reply) do
    PostCreator.create!(
      reply_user,
      topic_id: topic.id,
      raw: "This is a reply",
      reply_to_post_number: topic.first_post.post_number,
    )
  end
  fab!(:small_action) do
    Fabricate(:post, topic: topic, user: reply_user, post_type: Post.types[:small_action])
  end

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:post_created")
    end
  end

  describe ".event_name" do
    it "returns the correct event name" do
      expect(described_class.event_name).to eq(:post_created)
    end
  end

  describe "#valid?" do
    it "returns true for regular posts" do
      trigger = described_class.new(reply)
      expect(trigger.valid?).to eq(true)
    end

    it "returns false when post is nil" do
      trigger = described_class.new(nil)
      expect(trigger.valid?).to eq(false)
    end

    it "returns false for non-regular posts" do
      trigger = described_class.new(small_action)
      expect(trigger.valid?).to eq(false)
    end

    it "returns false when workflows are explicitly skipped" do
      trigger = described_class.new(reply, { skip_workflows: true })
      expect(trigger.valid?).to eq(false)
    end
  end

  describe "#output" do
    it "returns post and topic data" do
      trigger = described_class.new(reply)
      output = trigger.output

      expect(output[:post_id]).to eq(reply.id)
      expect(output[:post_number]).to eq(reply.post_number)
      expect(output[:post_raw]).to eq(reply.raw)
      expect(output[:reply_to_post_number]).to eq(topic.first_post.post_number)
      expect(output[:is_first_post]).to eq(false)
      expect(output[:via_email]).to eq(false)
      expect(output[:topic_id]).to eq(topic.id)
      expect(output[:topic_title]).to eq(topic.title)
      expect(output[:tags]).to eq(["test-tag"])
      expect(output[:category_id]).to eq(topic.category_id)
      expect(output[:user_id]).to eq(reply_user.id)
      expect(output[:username]).to eq(reply_user.username)
      expect(output[:archetype]).to eq(topic.archetype)
    end
  end
end
