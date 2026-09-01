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
  let(:ticket_request) do
    stub_request(:post, zendesk_api_ticket_url).to_return(
      status: 200,
      body: ticket_response,
      headers: default_header,
    )
  end

  before do
    SiteSetting.zendesk_enabled = true
    SiteSetting.zendesk_jobs_email = "zendesk@example.com"
    SiteSetting.zendesk_jobs_api_token = "api-token"

    ticket_request
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
    it "lets staff create a Zendesk ticket by default" do
      moderator = Fabricate(:moderator)
      topic = Fabricate(:post).topic
      sign_in(moderator)

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(200)
      expect(ticket_request).to have_been_requested.once
    end

    it "lets a member of a custom create group create a Zendesk ticket" do
      create_group = Fabricate(:group)
      creator = Fabricate(:user)
      create_group.add(creator)
      SiteSetting.zendesk_create_ticket_allowed_groups = create_group.id
      topic = Fabricate(:post).topic
      sign_in(creator)

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(200)
      expect(ticket_request).to have_been_requested.once
    end

    it "rejects staff after staff is removed from the allowed groups" do
      moderator = Fabricate(:moderator)
      SiteSetting.zendesk_create_ticket_allowed_groups = ""
      SiteSetting.zendesk_view_ticket_allowed_groups = ""
      topic = Fabricate(:post).topic
      sign_in(moderator)

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(403)
      expect(ticket_request).not_to have_been_requested
    end

    it "rejects members who can only view Zendesk tickets" do
      view_group = Fabricate(:group)
      viewer = Fabricate(:user)
      view_group.add(viewer)
      SiteSetting.zendesk_create_ticket_allowed_groups = ""
      SiteSetting.zendesk_view_ticket_allowed_groups = view_group.id
      topic = Fabricate(:post).topic
      sign_in(viewer)

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(403)
      expect(ticket_request).not_to have_been_requested
    end

    it "rejects allowed members while Zendesk credentials are incomplete" do
      create_group = Fabricate(:group)
      creator = Fabricate(:user)
      create_group.add(creator)
      SiteSetting.zendesk_create_ticket_allowed_groups = create_group.id
      SiteSetting.zendesk_jobs_api_token = ""
      topic = Fabricate(:post).topic
      sign_in(creator)

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(403)
      expect(ticket_request).not_to have_been_requested
    end

    it "rejects allowed members while the Zendesk URL is blank" do
      create_group = Fabricate(:group)
      creator = Fabricate(:user)
      create_group.add(creator)
      SiteSetting.zendesk_create_ticket_allowed_groups = create_group.id
      SiteSetting.zendesk_url = ""
      topic = Fabricate(:post).topic
      sign_in(creator)

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(403)
      expect(ticket_request).not_to have_been_requested
    end

    it "rejects staff who cannot view the topic" do
      admin = Fabricate(:admin)
      moderator = Fabricate(:moderator)
      pm = Fabricate(:private_message_topic, user: admin)
      Fabricate(:post, topic: pm)

      sign_in(moderator)

      post "/zendesk-plugin/issues.json", params: { topic_id: pm.id }

      expect(response.status).to eq(403)
      expect(ticket_request).not_to have_been_requested
    end

    it "rejects anonymous users" do
      topic = Fabricate(:post).topic

      post "/zendesk-plugin/issues.json", params: { topic_id: topic.id }

      expect(response.status).to eq(403)
      expect(ticket_request).not_to have_been_requested
    end
  end
end
