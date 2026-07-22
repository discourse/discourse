# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicCreated::V1 do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: user, raw: "First post") }
  fab!(:topic) { first_post.topic }
  fab!(:subcategory) { Fabricate(:category, parent_category: topic.category) }
  fab!(:subcategory_topic) { Fabricate(:topic, category: subcategory, user: user) }
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }
  fab!(:group_inbox, :group)
  fab!(:other_group, :group)
  fab!(:group_pm_topic) do
    Fabricate(:group_private_message_topic, user: user, recipient_group: group_inbox)
  end
  fab!(:direct_pm_topic) { Fabricate(:private_message_topic, user: user) }

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

  describe "#matches?" do
    it "matches topics in subcategories by default" do
      expect(
        described_class.new(subcategory_topic).matches?(
          trigger_context("category_ids" => [topic.category_id.to_s]),
        ),
      ).to eq(true)
    end

    it "does not match topics in subcategories when subcategories are excluded" do
      expect(
        described_class.new(subcategory_topic).matches?(
          trigger_context(
            "category_ids" => [topic.category_id.to_s],
            "include_subcategories" => false,
          ),
        ),
      ).to eq(false)
    end

    it "matches topics in the selected category when subcategories are excluded" do
      expect(
        described_class.new(topic).matches?(
          trigger_context(
            "category_ids" => [topic.category_id.to_s],
            "include_subcategories" => false,
          ),
        ),
      ).to eq(true)
    end

    it "matches topics in any of the configured categories" do
      other_category = Fabricate(:category)

      expect(
        described_class.new(topic).matches?(
          trigger_context("category_ids" => [other_category.id.to_s, topic.category_id.to_s]),
        ),
      ).to eq(true)
    end

    it "does not match topics outside the configured categories" do
      expect(
        described_class.new(topic).matches?(
          trigger_context("category_ids" => [Fabricate(:category).id.to_s]),
        ),
      ).to eq(false)
    end

    it "matches all categories when the configured list is empty" do
      expect(described_class.new(topic).matches?(trigger_context("category_ids" => []))).to eq(
        true,
      )
    end

    it "expands subcategories for every configured category" do
      other_parent = Fabricate(:category)
      other_subcategory = Fabricate(:category, parent_category: other_parent)
      other_subcategory_topic = Fabricate(:topic, category: other_subcategory, user: user)

      parameters =
        trigger_context("category_ids" => [topic.category_id.to_s, other_parent.id.to_s])

      expect(described_class.new(subcategory_topic).matches?(parameters)).to eq(true)
      expect(described_class.new(other_subcategory_topic).matches?(parameters)).to eq(true)
    end

    it "supports the legacy scalar category_id parameter" do
      expect(
        described_class.new(topic).matches?(
          trigger_context("category_id" => topic.category_id.to_s),
        ),
      ).to eq(true)
      expect(
        described_class.new(topic).matches?(
          trigger_context("category_id" => Fabricate(:category).id.to_s),
        ),
      ).to eq(false)
    end

    it "prefers category_ids over a stale category_id parameter" do
      expect(
        described_class.new(topic).matches?(
          trigger_context(
            "category_ids" => [Fabricate(:category).id.to_s],
            "category_id" => topic.category_id.to_s,
          ),
        ),
      ).to eq(false)
    end

    it "does not match when the configured value is an unresolved expression" do
      expect(
        described_class.new(topic).matches?(trigger_context("category_ids" => ["=$json.x"])),
      ).to eq(false)
    end

    it "matches only topics when topic type is blank" do
      expect(described_class.new(topic).matches?(trigger_context({}))).to eq(true)
      expect(described_class.new(group_pm_topic).matches?(trigger_context({}))).to eq(false)
    end

    it "matches topics and personal messages when topic type is all" do
      expect(described_class.new(topic).matches?(trigger_context("topic_type" => "all"))).to eq(
        true,
      )
      expect(
        described_class.new(group_pm_topic).matches?(trigger_context("topic_type" => "all")),
      ).to eq(true)
    end

    it "matches only topics when topic type is topics" do
      expect(described_class.new(topic).matches?(trigger_context("topic_type" => "topics"))).to eq(
        true,
      )
      expect(
        described_class.new(group_pm_topic).matches?(trigger_context("topic_type" => "topics")),
      ).to eq(false)
    end

    it "matches only personal messages when topic type is personal messages" do
      expect(
        described_class.new(group_pm_topic).matches?(
          trigger_context("topic_type" => "personal_messages"),
        ),
      ).to eq(true)
      expect(
        described_class.new(topic).matches?(trigger_context("topic_type" => "personal_messages")),
      ).to eq(false)
    end

    it "matches personal messages in the configured group inbox" do
      expect(
        described_class.new(group_pm_topic).matches?(
          trigger_context(
            "topic_type" => "personal_messages",
            "group_inbox_id" => group_inbox.id.to_s,
          ),
        ),
      ).to eq(true)
    end

    it "does not match personal messages outside the configured group inbox" do
      expect(
        described_class.new(group_pm_topic).matches?(
          trigger_context(
            "topic_type" => "personal_messages",
            "group_inbox_id" => other_group.id.to_s,
          ),
        ),
      ).to eq(false)
      expect(
        described_class.new(direct_pm_topic).matches?(
          trigger_context(
            "topic_type" => "personal_messages",
            "group_inbox_id" => group_inbox.id.to_s,
          ),
        ),
      ).to eq(false)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
