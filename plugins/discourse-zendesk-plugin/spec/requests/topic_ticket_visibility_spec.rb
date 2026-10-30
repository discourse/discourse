# frozen_string_literal: true

RSpec.describe TopicsController do
  fab!(:topic)
  fab!(:first_post) { Fabricate(:post, topic: topic) }
  fab!(:user)
  fab!(:group)

  before do
    SiteSetting.zendesk_enabled = true
    topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = "123"
    topic.save_custom_fields
  end

  describe "#show" do
    it "hides Zendesk metadata from guests and unrelated users" do
      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_zendesk_id")
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_zendesk_url")
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_has_ticket")

      sign_in(user)
      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_zendesk_id")
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_zendesk_url")
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_has_ticket")
    end

    it "preserves staff ticket metadata when disabled without granting group access" do
      group.add(user)
      SiteSetting.zendesk_view_ticket_allowed_groups = group.id.to_s
      SiteSetting.zendesk_enabled = false
      sign_in(Fabricate(:admin))

      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["discourse_zendesk_plugin_zendesk_id"]).to eq("123")
      expect(response.parsed_body["discourse_zendesk_plugin_zendesk_url"]).to eq(
        "https://your-url.zendesk.com/agent/tickets/123",
      )

      sign_in(user)
      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_zendesk_id")
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_zendesk_url")
    end

    it "exposes the ticket link only to viewing groups" do
      group.add(user)
      SiteSetting.zendesk_view_ticket_allowed_groups = group.id.to_s
      sign_in(user)

      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["discourse_zendesk_plugin_zendesk_id"]).to eq("123")
      expect(response.parsed_body["discourse_zendesk_plugin_zendesk_url"]).to eq(
        "https://your-url.zendesk.com/agent/tickets/123",
      )
    end
  end
end
