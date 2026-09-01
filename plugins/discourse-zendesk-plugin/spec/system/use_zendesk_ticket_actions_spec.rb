# frozen_string_literal: true

RSpec.describe "Zendesk ticket actions" do
  fab!(:topic) { Fabricate(:post).topic }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:zendesk_actions) { PageObjects::Components::ZendeskTopicActions.new }
  let(:zendesk_api_url) { "https://your-url.zendesk.com/api/v2" }
  let(:ticket_url) { "https://your-url.zendesk.com/agent/tickets/ticket-id" }

  before do
    SiteSetting.zendesk_enabled = true
    SiteSetting.zendesk_jobs_email = "zendesk@example.com"
    SiteSetting.zendesk_jobs_api_token = "api-token"

    stub_request(:get, "#{zendesk_api_url}/users/me").to_return(
      status: 200,
      body: { user: {} }.to_json,
      headers: {
        "Content-Type" => "application/json; charset=UTF-8",
      },
    )
    stub_request(:get, %r{/users/search}).to_return(
      status: 200,
      body: { users: [{ id: 24 }] }.to_json,
      headers: {
        "Content-Type" => "application/json; charset=UTF-8",
      },
    )
    stub_request(:post, "#{zendesk_api_url}/tickets").to_return(
      status: 200,
      body: {
        ticket: {
          id: "ticket-id",
          url: "ticket-api-url",
        },
        audit: {
          events: [{ id: "comment-id", type: "Comment" }],
        },
      }.to_json,
      headers: {
        "Content-Type" => "application/json; charset=UTF-8",
      },
    )
  end

  it "lets a create-group member create and then view a Zendesk ticket" do
    create_group = Fabricate(:group)
    creator = Fabricate(:user)
    create_group.add(creator)
    SiteSetting.zendesk_create_ticket_allowed_groups = create_group.id
    SiteSetting.zendesk_view_ticket_allowed_groups = ""
    sign_in(creator)
    topic_page.visit_topic(topic)

    expect(zendesk_actions).to have_create_action

    zendesk_actions.click_create

    expect(zendesk_actions).to have_view_action(ticket_url)
  end

  it "shows a view-group member the existing Zendesk ticket action" do
    view_group = Fabricate(:group)
    viewer = Fabricate(:user)
    view_group.add(viewer)
    SiteSetting.zendesk_create_ticket_allowed_groups = ""
    SiteSetting.zendesk_view_ticket_allowed_groups = view_group.id
    topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = "ticket-id"
    topic.save_custom_fields
    sign_in(viewer)

    topic_page.visit_topic(topic)

    expect(zendesk_actions).to have_view_action(ticket_url)
  end

  it "keeps Zendesk ticket actions hidden from users outside the allowed groups" do
    sign_in(Fabricate(:user))

    topic_page.visit_topic(topic)

    expect(zendesk_actions).to have_no_actions
  end

  it "keeps Zendesk ticket actions and the setup warning hidden when the Zendesk URL is blank" do
    SiteSetting.zendesk_url = ""
    sign_in(Fabricate(:moderator))

    topic_page.visit_topic(topic)

    expect(zendesk_actions).to have_no_actions
    expect(zendesk_actions).to have_no_credentials_warning
  end
end
