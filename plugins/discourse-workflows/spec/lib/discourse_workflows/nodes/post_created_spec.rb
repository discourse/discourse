# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostCreated::V1 do
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
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe "#valid?" do
    it "returns true for regular posts" do
      trigger = described_class.new(reply)
      expect(trigger).to be_valid
    end

    it "returns false when post is nil" do
      trigger = described_class.new(nil)
      expect(trigger).not_to be_valid
    end

    it "returns false for non-regular posts" do
      trigger = described_class.new(small_action)
      expect(trigger).not_to be_valid
    end

    it "returns false when workflows are explicitly skipped" do
      trigger = described_class.new(reply, { skip_workflows: true })
      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns post and topic data" do
      trigger = described_class.new(reply)
      output = trigger.output

      expect(output[:post][:id]).to eq(reply.id)
      expect(output[:post][:post_number]).to eq(reply.post_number)
      expect(output[:post][:raw]).to eq(reply.raw)
      expect(output[:post][:reply_to_post_number]).to eq(topic.first_post.post_number)
      expect(output[:post][:is_first_post]).to be(false)
      expect(output[:post][:via_email]).to be(false)
      expect(output[:post][:user_id]).to eq(reply_user.id)
      expect(output[:post][:username]).to eq(reply_user.username)
      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:topic][:title]).to eq(topic.title)
      expect(output[:topic][:tags]).to eq(["test-tag"])
      expect(output[:topic][:category_id]).to eq(topic.category_id)
      expect(output[:topic][:archetype]).to eq(topic.archetype)
    end
  end
end
