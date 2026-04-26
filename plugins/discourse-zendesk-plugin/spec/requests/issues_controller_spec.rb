# frozen_string_literal: true

RSpec.describe DiscourseZendeskPlugin::IssuesController do
  let(:zendesk_url_default) { "https://your-url.zendesk.com/api/v2" }
  let(:zendesk_api_ticket_url) { zendesk_url_default + "/tickets" }
  let(:zendesk_api_user_create_url) { zendesk_url_default + "/users" }
  let(:ticket_response) { { ticket: { id: "ticket_id", url: "ticket_url" } }.to_json }
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
    stub_request(:get, %r{/tickets/.*/comments}).to_return(status: 200)
    stub_request(:get, %r{/users/search}).to_return(
      status: 200,
      body: { user: {} }.to_json,
      headers: default_header,
    )
  end

  describe "#create" do
    it "creates a zendesk ticket for a topic" do
      moderator = Fabricate(:moderator)
      topic = Fabricate(:topic)

      Fabricate(:post, topic: topic)

      sign_in(moderator)

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(200)
      expect(WebMock).to have_requested(:post, zendesk_api_ticket_url)
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
