# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::DiscourseChatMigrateFromSlackOfficial do
  let(:category) { Fabricate(:category) }

  describe "site settings" do
    before do
      PluginStoreRow.create!(
        plugin_name: "discourse-slack-official",
        key: "category_#{category.id}",
        type_name: "JSON",
        value: "[{\"channel\":\"#slack-channel\",\"filter\":\"mute\"}]",
      )

      SiteSetting.create!(value: "t", data_type: 5, name: "slack_enabled")
      SiteSetting.create!(value: "token", data_type: 1, name: "slack_access_token")
      SiteSetting.create!(value: "token2", data_type: 1, name: "slack_incoming_webhook_token")
      SiteSetting.create!(value: 300, data_type: 3, name: "slack_discourse_excerpt_length")
      SiteSetting.create!(
        value: "https://hooks.slack.com/services/something",
        data_type: 1,
        name: "slack_outbound_webhook_url",
      )
      SiteSetting.create!(value: "http://outbound2.com", data_type: 1, name: "slack_icon_url")
      SiteSetting.create!(value: 100, data_type: 3, name: "post_to_slack_window_secs")
      SiteSetting.create!(value: User.last.username, data_type: 1, name: "slack_discourse_username")
    end

    it "should migrate the site settings correctly" do
      described_class.new.execute_onceoff({})

      expect(SiteSetting.find_by(name: "slack_enabled").value).to eq("f")
      expect(SiteSetting.chat_integration_slack_access_token).to eq("token")
      expect(SiteSetting.chat_integration_slack_incoming_webhook_token).to eq("token2")
      expect(SiteSetting.chat_integration_slack_excerpt_length).to eq(300)

      expect(SiteSetting.chat_integration_slack_outbound_webhook_url).to eq(
        "https://hooks.slack.com/services/something",
      )

      expect(SiteSetting.chat_integration_slack_icon_url).to eq("http://outbound2.com")

      expect(SiteSetting.chat_integration_delay_seconds).to eq(100)
      expect(SiteSetting.chat_integration_discourse_username).to eq(User.last.username)
      expect(SiteSetting.chat_integration_slack_enabled).to eq(true)
      expect(SiteSetting.chat_integration_enabled).to eq(true)
    end

    describe "when slack_discourse_username is not valid" do
      before { SiteSetting.find_by(name: "slack_discourse_username").update!(value: "someguy") }

      it "should default to the system user" do
        described_class.new.execute_onceoff({})

        expect(SiteSetting.chat_integration_discourse_username).to eq(
          Discourse.system_user.username,
        )
      end
    end
  end

  describe "when a uncategorized filter is present" do
    before do
      PluginStoreRow.create!(
        plugin_name: "discourse-slack-official",
        key: "category_*",
        type_name: "JSON",
        value:
          "[{\"channel\":\"#channel1\",\"filter\":\"watch\"},{\"channel\":\"channel2\",\"filter\":\"follow\"},{\"channel\":\"#channel1\",\"filter\":\"mute\"}]",
      )
    end

    it "should create the right channels and rules" do
      described_class.new.execute_onceoff({})

      expect(DiscourseChatIntegration::Channel.count).to eq(2)
      expect(DiscourseChatIntegration::Rule.count).to eq(2)

      channel = DiscourseChatIntegration::Channel.first

      expect(channel.value["provider"]).to eq("slack")
      expect(channel.value["data"]["identifier"]).to eq("#channel1")

      rule = DiscourseChatIntegration::Rule.first

      expect(rule.value["channel_id"]).to eq(channel.id)
      expect(rule.value["filter"]).to eq("mute")
      expect(rule.value["category_id"]).to eq(nil)

      channel = DiscourseChatIntegration::Channel.last

      expect(channel.value["provider"]).to eq("slack")
      expect(channel.value["data"]["identifier"]).to eq("#channel2")

      rule = DiscourseChatIntegration::Rule.last

      expect(rule.value["channel_id"]).to eq(channel.id)
      expect(rule.value["filter"]).to eq("follow")
      expect(rule.value["category_id"]).to eq(nil)
    end
  end

  describe "when filter contains an invalid tag" do
    let(:tag) { Fabricate(:tag) }

    before do
      PluginStoreRow.create!(
        plugin_name: "discourse-slack-official",
        key: "category_#{category.id}",
        type_name: "JSON",
        value:
          "[{\"channel\":\"#slack-channel\",\"filter\":\"mute\",\"tags\":[\"#{tag.name}\",\"random-tag\"]}]",
      )
    end

    it "should discard invalid tags" do
      described_class.new.execute_onceoff({})

      rule = DiscourseChatIntegration::Rule.first

      expect(rule.value["tags"]).to eq([tag.name])
    end
  end

  describe "when a category filter is present" do
    before do
      PluginStoreRow.create!(
        plugin_name: "discourse-slack-official",
        key: "category_#{category.id}",
        type_name: "JSON",
        value: "[{\"channel\":\"#slack-channel\",\"filter\":\"mute\"}]",
      )
    end

    it "should migrate the settings correctly" do
      described_class.new.execute_onceoff({})

      channel = DiscourseChatIntegration::Channel.first

      expect(channel.value["provider"]).to eq("slack")
      expect(channel.value["data"]["identifier"]).to eq("#slack-channel")

      rule = DiscourseChatIntegration::Rule.first

      expect(rule.value["channel_id"]).to eq(channel.id)
      expect(rule.value["filter"]).to eq("mute")
      expect(rule.value["category_id"]).to eq(category.id)
    end
  end

  describe "when a category has been deleted" do
    before do
      PluginStoreRow.create!(
        plugin_name: "discourse-slack-official",
        key: "category_9999",
        type_name: "JSON",
        value: "[{\"channel\":\"#slack-channel\",\"filter\":\"mute\"}]",
      )
    end

    it "should not migrate the settings" do
      described_class.new.execute_onceoff({})

      expect(DiscourseChatIntegration::Channel.count).to eq(0)
      expect(DiscourseChatIntegration::Rule.count).to eq(0)
    end
  end
end
