# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostCreated::V1 do
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:reply_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }
  fab!(:subcategory) { Fabricate(:category, parent_category: topic.category) }
  fab!(:subcategory_topic) { Fabricate(:topic, category: subcategory, user: topic_owner) }
  fab!(:subcategory_post) { Fabricate(:post, topic: subcategory_topic, user: reply_user) }
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }
  fab!(:group_inbox, :group)
  fab!(:other_group, :group)
  fab!(:group_pm_topic) do
    Fabricate(:group_private_message_topic, user: topic_owner, recipient_group: group_inbox)
  end
  fab!(:direct_pm_topic) { Fabricate(:private_message_topic, user: topic_owner) }
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
    it "returns post and topic data", :aggregate_failures do
      upload = Fabricate(:image_upload)
      UploadReference.create!(target: reply, upload: upload)

      trigger = described_class.new(reply)
      output = trigger.output

      expect(output[:post][:id]).to eq(reply.id)
      expect(output[:post][:post_number]).to eq(reply.post_number)
      expect(output[:post][:raw]).to eq(reply.raw)
      expect(output[:post][:reply_to_post_number]).to eq(topic.first_post.post_number)
      expect(output[:post][:user_id]).to eq(reply_user.id)
      expect(output[:post][:username]).to eq(reply_user.username)
      expect(output[:post][:upload_ids]).to contain_exactly(upload.id)
      expect(output[:user]).to include(
        id: reply_user.id,
        username: reply_user.username,
        trust_level: reply_user.trust_level,
        trust_level_name: TrustLevel.name(reply_user.trust_level),
        admin: false,
        moderator: false,
        staff: false,
      )
      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:topic][:title]).to eq(topic.title)
      expect(output[:topic][:tags].map { |topic_tag| topic_tag[:name] }).to eq(["test-tag"])
      expect(output[:topic][:category_id]).to eq(topic.category_id)
      expect(output[:topic][:archetype]).to eq(topic.archetype)
      expect(output).to match_node_output_schema(described_class)
    end

    it "returns personal message data without a category", :aggregate_failures do
      personal_message_post = Fabricate(:post, topic: direct_pm_topic, user: reply_user)
      output = described_class.new(personal_message_post).output

      expect(output.dig(:post, :category_id)).to be_nil
      expect(output.dig(:topic, :category_id)).to be_nil
      expect(output).to match_node_output_schema(described_class)
    end
  end

  describe "#matches?" do
    it "matches posts in subcategories by default" do
      expect(
        described_class.new(subcategory_post).matches?(
          trigger_context("category_id" => topic.category_id.to_s),
        ),
      ).to eq(true)
    end

    it "does not match posts in subcategories when subcategories are excluded" do
      expect(
        described_class.new(subcategory_post).matches?(
          trigger_context(
            "category_id" => topic.category_id.to_s,
            "include_subcategories" => false,
          ),
        ),
      ).to eq(false)
    end

    it "matches posts in the selected category when subcategories are excluded" do
      expect(
        described_class.new(reply).matches?(
          trigger_context(
            "category_id" => topic.category_id.to_s,
            "include_subcategories" => false,
          ),
        ),
      ).to eq(true)
    end

    it "matches only topics when topic type is blank" do
      group_pm_post = Fabricate(:post, topic: group_pm_topic, user: reply_user)

      expect(described_class.new(reply).matches?(trigger_context({}))).to eq(true)
      expect(described_class.new(group_pm_post).matches?(trigger_context({}))).to eq(false)
    end

    it "matches topics and personal messages when topic type is all" do
      group_pm_post = Fabricate(:post, topic: group_pm_topic, user: reply_user)

      expect(described_class.new(reply).matches?(trigger_context("topic_type" => "all"))).to eq(
        true,
      )
      expect(
        described_class.new(group_pm_post).matches?(trigger_context("topic_type" => "all")),
      ).to eq(true)
    end

    it "returns true when the post topic matches the configured category and tags" do
      trigger = described_class.new(reply)

      expect(
        trigger.matches?(
          trigger_context("category_id" => topic.category_id.to_s, "tag_names" => [tag.name]),
        ),
      ).to eq(true)
    end

    it "returns false when the post topic does not match the configured category or tags" do
      other_category = Fabricate(:category)
      trigger = described_class.new(reply)

      expect(trigger.matches?(trigger_context("category_id" => other_category.id.to_s))).to eq(
        false,
      )
      expect(trigger.matches?(trigger_context("tag_names" => ["missing"]))).to eq(false)
    end

    it "matches only topics when topic type is topics" do
      group_pm_post = Fabricate(:post, topic: group_pm_topic, user: reply_user)

      expect(described_class.new(reply).matches?(trigger_context("topic_type" => "topics"))).to eq(
        true,
      )
      expect(
        described_class.new(group_pm_post).matches?(trigger_context("topic_type" => "topics")),
      ).to eq(false)
    end

    it "matches only personal messages when topic type is personal messages" do
      group_pm_post = Fabricate(:post, topic: group_pm_topic, user: reply_user)

      expect(
        described_class.new(group_pm_post).matches?(
          trigger_context("topic_type" => "personal_messages"),
        ),
      ).to eq(true)
      expect(
        described_class.new(reply).matches?(trigger_context("topic_type" => "personal_messages")),
      ).to eq(false)
    end

    it "matches personal messages in the configured group inbox" do
      group_pm_post = Fabricate(:post, topic: group_pm_topic, user: reply_user)

      expect(
        described_class.new(group_pm_post).matches?(
          trigger_context(
            "topic_type" => "personal_messages",
            "group_inbox_id" => group_inbox.id.to_s,
          ),
        ),
      ).to eq(true)
    end

    it "does not match personal messages outside the configured group inbox" do
      group_pm_post = Fabricate(:post, topic: group_pm_topic, user: reply_user)
      direct_pm_post = Fabricate(:post, topic: direct_pm_topic, user: reply_user)

      expect(
        described_class.new(group_pm_post).matches?(
          trigger_context(
            "topic_type" => "personal_messages",
            "group_inbox_id" => other_group.id.to_s,
          ),
        ),
      ).to eq(false)
      expect(
        described_class.new(direct_pm_post).matches?(
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
