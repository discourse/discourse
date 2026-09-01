# frozen_string_literal: true

RSpec.describe WebHookTopicViewSerializer do
  fab!(:topic) do
    Fabricate(:post).topic.tap do |topic|
      topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = "ticket-id"
      topic.save_custom_fields
    end
  end

  let(:payload) do
    described_class.new(
      TopicView.new(topic),
      scope: Guardian.new(Discourse.system_user),
      root: false,
    ).as_json
  end

  before do
    SiteSetting.zendesk_enabled = true
    SiteSetting.zendesk_jobs_email = "zendesk@example.com"
    SiteSetting.zendesk_jobs_api_token = "api-token"
  end

  it "includes Zendesk ticket data when the system user can view tickets" do
    expect(payload).to include(
      DiscourseZendeskPlugin::ZENDESK_ID_FIELD.to_sym => "ticket-id",
      DiscourseZendeskPlugin::ZENDESK_URL_FIELD.to_sym =>
        "https://your-url.zendesk.com/agent/tickets/ticket-id",
    )
    expect(payload).not_to have_key(:can_create_zendesk_ticket)
    expect(payload).not_to have_key(:can_view_zendesk_ticket)
  end

  it "omits Zendesk ticket data when the system user cannot view tickets" do
    SiteSetting.zendesk_create_ticket_allowed_groups = ""
    SiteSetting.zendesk_view_ticket_allowed_groups = ""

    expect(payload).not_to have_key(DiscourseZendeskPlugin::ZENDESK_ID_FIELD.to_sym)
    expect(payload).not_to have_key(DiscourseZendeskPlugin::ZENDESK_URL_FIELD.to_sym)
  end
end
