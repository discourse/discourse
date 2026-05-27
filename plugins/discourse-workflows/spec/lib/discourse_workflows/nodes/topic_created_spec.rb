# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicCreated::V1 do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: user, raw: "First post") }
  fab!(:topic) { first_post.topic }
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  before do
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe "#valid?" do
    it "returns true when topic is present" do
      trigger = described_class.new(topic)
      expect(trigger).to be_valid
    end

    it "returns false when topic is nil" do
      trigger = described_class.new(nil)
      expect(trigger).not_to be_valid
    end

    it "returns false when skip_workflows is true" do
      trigger = described_class.new(topic, { skip_workflows: true })
      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns post and topic data" do
      trigger = described_class.new(topic)
      output = trigger.output

      expect(output[:post][:id]).to eq(first_post.id)
      expect(output[:post][:post_number]).to eq(first_post.post_number)
      expect(output[:post][:raw]).to eq(first_post.raw)
      expect(output[:post][:user_id]).to eq(user.id)
      expect(output[:post][:username]).to eq(user.username)
      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:topic][:title]).to eq(topic.title)
      expect(output[:topic][:tags].map { |topic_tag| topic_tag[:name] }).to eq(["test-tag"])
      expect(output[:topic][:category_id]).to eq(topic.category_id)
      expect(output[:topic][:posters].map { |poster| poster[:user_id] }).to include(topic.user_id)
    end

    it "includes assignment data when assign is available" do
      SiteSetting.assign_enabled = true
      assignee = Fabricate(:user)
      Fabricate(:topic_assignment, topic: topic, assigned_to: assignee)

      output = described_class.new(topic).output

      expect(output[:topic][:assigned_to_user][:username]).to eq(assignee.username)
    end
  end
end
