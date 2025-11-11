# frozen_string_literal: true
require_relative "../dummy_provider"
RSpec.describe "Triggering notifications" do
  include_context "with validated dummy provider"

  context "with automation installed", if: defined?(DiscourseAutomation) do
    fab!(:admin)
    fab!(:category)
    fab!(:tag)
    let(:valid_attrs) { Fabricate.attributes_for(:topic) }

    fab!(:automation) do
      Fabricate(
        :automation,
        script: "send_chat_integration_message",
        trigger: "topic_tags_changed",
        enabled: true,
      )
    end
    let(:channel1) do
      DiscourseChatIntegration::Channel.create!(provider: "dummy2", data: { val: "channel" })
    end

    before do
      SiteSetting.chat_integration_enabled = true
      SiteSetting.discourse_automation_enabled = true

      SiteSetting.tagging_enabled = true
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:everyone]
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:everyone]

      automation.upsert_field!(
        "watching_categories",
        "categories",
        { "value" => [category.id] },
        target: "trigger",
      )
      automation.upsert_field!(
        "watching_tags",
        "tags",
        { "value" => [tag.name] },
        target: "trigger",
      )
      automation.upsert_field!(
        "provider",
        "choices",
        { "value" => channel1.provider },
        target: "script",
      )
      automation.upsert_field!("channel_name", "text", { "value" => "channel" }, target: "script")
    end

    it "triggers a notification" do
      topic = Fabricate(:topic, user: admin, tags: [], category: category)

      DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), [tag.name])

      expect(validated_provider.sent_messages.length).to eq(1)
      expect(validated_provider.sent_messages.first[:post]).to eq(topic.id)
      expect(validated_provider.sent_messages.first[:channel]).to eq(channel1)
    end

    it "only triggers for the correct tag" do
      topic = Fabricate(:topic, user: admin, tags: [], category: category)

      DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), ["other_tag"])

      expect(validated_provider.sent_messages.length).to eq(0)
    end

    it "only triggers for the correct category" do
      topic = Fabricate(:topic, user: admin, tags: [], category: Fabricate(:category))

      DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), [tag.name])

      expect(validated_provider.sent_messages.length).to eq(0)
    end

    it "should not trigger a provider notification on topic creation for topic_tags_changed script" do
      TopicCreator.create(
        admin,
        Guardian.new(admin),
        valid_attrs.merge(tags: [tag.name], category: category.id),
      )
      expect(validated_provider.sent_messages.length).to eq(0)
    end
  end
end
