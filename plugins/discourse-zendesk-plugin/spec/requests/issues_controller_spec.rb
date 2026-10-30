# frozen_string_literal: true

RSpec.describe DiscourseZendeskPlugin::IssuesController do
  let(:zendesk_url_default) { "https://your-url.zendesk.com/api/v2" }
  let(:zendesk_api_ticket_url) { zendesk_url_default + "/tickets" }
  let(:zendesk_api_user_create_url) { zendesk_url_default + "/users" }
  let(:ticket_response) do
    {
      ticket: {
        id: "ticket_id",
        url: "ticket_url",
      },
      audit: {
        events: [{ id: "comment_id", type: "Comment" }],
      },
    }.to_json
  end
  let(:default_header) { { "Content-Type" => "application/json; charset=UTF-8" } }

  before do
    SiteSetting.zendesk_enabled = true

    stub_request(:post, zendesk_api_ticket_url).to_return(
      status: 200,
      body: ticket_response,
      headers: default_header,
    )
    stub_request(:get, zendesk_url_default + "/users/me").to_return(
      status: 200,
      body: { user: {} }.to_json,
      headers: default_header,
    )
    stub_request(:post, zendesk_api_user_create_url).to_return(
      status: 200,
      body: { user: { id: 24 } }.to_json,
      headers: default_header,
    )
    stub_request(:get, %r{/users/search}).to_return(
      status: 200,
      body: { users: [] }.to_json,
      headers: default_header,
    )
  end

  describe "#create" do
    fab!(:support_group, :group)
    fab!(:support_user, :user)
    fab!(:topic)
    fab!(:first_post) { Fabricate(:post, topic: topic) }

    it "allows a creation group member without revealing the ticket link" do
      support_group.add(support_user)
      SiteSetting.zendesk_create_ticket_allowed_groups = support_group.id.to_s
      sign_in(support_user)

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(200)
      expect(response.parsed_body["discourse_zendesk_plugin_has_ticket"]).to eq(true)
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_zendesk_id")
      expect(response.parsed_body).not_to have_key("discourse_zendesk_plugin_zendesk_url")
      expect(WebMock).to have_requested(:post, zendesk_api_ticket_url).once

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(200)
      expect(WebMock).to have_requested(:post, zendesk_api_ticket_url).once
    end

    it "denies creation to a viewer and an unrelated user" do
      support_group.add(support_user)
      SiteSetting.zendesk_view_ticket_allowed_groups = support_group.id.to_s
      sign_in(support_user)

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(403)
      expect(WebMock).not_to have_requested(:post, zendesk_api_ticket_url)

      sign_in(Fabricate(:user))
      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(403)
      expect(WebMock).not_to have_requested(:post, zendesk_api_ticket_url)
    end

    it "requires login even when everyone has creation permission" do
      SiteSetting.zendesk_create_ticket_allowed_groups = Group::AUTO_GROUPS[:everyone].to_s

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(403)
      expect(WebMock).not_to have_requested(:post, zendesk_api_ticket_url)
    end

    it "denies creation for topics the creation group member cannot see" do
      support_group.add(support_user)
      SiteSetting.zendesk_create_ticket_allowed_groups = support_group.id.to_s
      private_topic = Fabricate(:private_message_topic)
      Fabricate(:post, topic: private_topic)
      sign_in(support_user)

      post "/zendesk-plugin/issues.json", params: { topic_id: private_topic.id }

      expect(response.status).to eq(403)
      expect(WebMock).not_to have_requested(:post, zendesk_api_ticket_url)
    end

    it "creates a zendesk ticket for a topic" do
      moderator = Fabricate(:moderator)
      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic)
      sign_in(moderator)
      SiteSetting.zendesk_oauth_client_id = "oauth-client-id"
      SiteSetting.zendesk_oauth_client_secret = "oauth-client-secret"
      stub_request(:post, "https://your-url.zendesk.com/oauth/tokens").to_return(
        status: 200,
        body: { access_token: "oauth-access-token", expires_in: 1800 }.to_json,
      )

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(200)
      expect(WebMock).to have_requested(:post, zendesk_api_ticket_url).with(
        headers: {
          "Authorization" => "Bearer oauth-access-token",
        },
      )
    end

    it "does not create a zendesk ticket for a topic the moderator cannot see" do
      admin = Fabricate(:admin)
      moderator = Fabricate(:moderator)
      pm = Fabricate(:private_message_topic, user: admin)
      Fabricate(:post, topic: pm)

      sign_in(moderator)

      post "/zendesk-plugin/issues.json", params: { topic_id: pm.id }

      expect(response.status).to eq(403)
      expect(WebMock).not_to have_requested(:post, zendesk_api_ticket_url)
    end
  end
end
