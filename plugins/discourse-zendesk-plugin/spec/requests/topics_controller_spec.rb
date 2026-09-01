# frozen_string_literal: true

RSpec.describe TopicsController do
  fab!(:topic) do
    Fabricate(:post).topic.tap do |topic|
      topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = "ticket-id"
      topic.save_custom_fields
    end
  end

  before do
    SiteSetting.zendesk_enabled = true
    SiteSetting.zendesk_jobs_email = "zendesk@example.com"
    SiteSetting.zendesk_jobs_api_token = "api-token"
  end

  describe "#show" do
    it "returns create and view access with ticket details for a create-group member" do
      create_group = Fabricate(:group)
      creator = Fabricate(:user)
      create_group.add(creator)
      SiteSetting.zendesk_create_ticket_allowed_groups = create_group.id
      SiteSetting.zendesk_view_ticket_allowed_groups = ""
      sign_in(creator)

      get "/t/#{topic.id}.json"

      expect(response.parsed_body).to include(
        "can_create_zendesk_ticket" => true,
        "can_view_zendesk_ticket" => true,
        DiscourseZendeskPlugin::ZENDESK_ID_FIELD => "ticket-id",
        DiscourseZendeskPlugin::ZENDESK_URL_FIELD =>
          "https://your-url.zendesk.com/agent/tickets/ticket-id",
      )
    end

    it "returns view access with ticket details for a view-group member" do
      view_group = Fabricate(:group)
      viewer = Fabricate(:user)
      view_group.add(viewer)
      SiteSetting.zendesk_create_ticket_allowed_groups = ""
      SiteSetting.zendesk_view_ticket_allowed_groups = view_group.id
      sign_in(viewer)

      get "/t/#{topic.id}.json"

      expect(response.parsed_body).to include(
        "can_create_zendesk_ticket" => false,
        "can_view_zendesk_ticket" => true,
        DiscourseZendeskPlugin::ZENDESK_ID_FIELD => "ticket-id",
        DiscourseZendeskPlugin::ZENDESK_URL_FIELD =>
          "https://your-url.zendesk.com/agent/tickets/ticket-id",
      )
    end

    it "returns no ticket access or details for users outside the allowed groups" do
      sign_in(Fabricate(:user))

      get "/t/#{topic.id}.json"

      expect(response.parsed_body).to include(
        "can_create_zendesk_ticket" => false,
        "can_view_zendesk_ticket" => false,
      )
      expect(response.parsed_body).not_to have_key(DiscourseZendeskPlugin::ZENDESK_ID_FIELD)
      expect(response.parsed_body).not_to have_key(DiscourseZendeskPlugin::ZENDESK_URL_FIELD)
    end

    it "returns no ticket access or details when Zendesk credentials are incomplete" do
      SiteSetting.zendesk_jobs_api_token = ""
      sign_in(Fabricate(:moderator))

      get "/t/#{topic.id}.json"

      expect(response.parsed_body).to include(
        "can_create_zendesk_ticket" => false,
        "can_view_zendesk_ticket" => false,
      )
      expect(response.parsed_body).not_to have_key(DiscourseZendeskPlugin::ZENDESK_ID_FIELD)
      expect(response.parsed_body).not_to have_key(DiscourseZendeskPlugin::ZENDESK_URL_FIELD)
    end
  end
end
