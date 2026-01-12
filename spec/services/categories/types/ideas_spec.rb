# frozen_string_literal: true

RSpec.describe Categories::Types::Ideas do
  describe ".available?" do
    context "when discourse-topic-voting is not loaded" do
      before { allow(described_class).to receive(:available?).and_call_original }

      it "returns false when DiscourseTopicVoting is not defined" do
        hide_const("DiscourseTopicVoting") if defined?(DiscourseTopicVoting)
        expect(described_class.available?).to be_falsey
      end
    end

    context "when discourse-topic-voting is loaded", if: defined?(DiscourseTopicVoting) do
      it "returns true" do
        expect(described_class.available?).to be true
      end
    end
  end

  describe ".type_id" do
    it "returns :ideas" do
      expect(described_class.type_id).to eq(:ideas)
    end
  end

  describe ".icon" do
    it "returns lightbulb" do
      expect(described_class.icon).to eq("lightbulb")
    end
  end

  describe ".enable_plugin", if: defined?(DiscourseTopicVoting) do
    it "enables the topic_voting_enabled setting" do
      SiteSetting.topic_voting_enabled = false

      described_class.enable_plugin

      expect(SiteSetting.topic_voting_enabled).to be true
    end
  end

  describe ".configure_category", if: defined?(DiscourseTopicVoting) do
    fab!(:category)

    it "sets the enable_topic_voting custom field" do
      described_class.configure_category(category)

      category.reload
      expect(category.custom_fields[DiscourseTopicVoting::ENABLE_TOPIC_VOTING_SETTING]).to be true
    end
  end
end
