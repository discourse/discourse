# frozen_string_literal: true

RSpec.describe "Create Zendesk ticket" do
  fab!(:user)
  fab!(:group)
  fab!(:topic)
  fab!(:first_post) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:actions) { PageObjects::Components::ZendeskTopicActions.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.zendesk_enabled = true
    SiteSetting.zendesk_jobs_email = "support@example.com"
    SiteSetting.zendesk_jobs_api_token = "test-token"
    stub_request(:get, %r{https://your-url.zendesk.com/api/v2/users/search}).to_return(
      status: 200,
      body: { users: [{ id: 24 }] }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )
    stub_request(:post, "https://your-url.zendesk.com/api/v2/tickets").to_return(
      status: 200,
      body: { ticket: { id: 123, url: "ticket-url" } }.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  it "lets a support group member create and view a ticket" do
    group.add(user)
    SiteSetting.zendesk_create_ticket_allowed_groups = group.id.to_s
    SiteSetting.zendesk_view_ticket_allowed_groups = group.id.to_s
    sign_in(user)

    topic_page.visit_topic(topic)
    actions.create_ticket

    expect(actions).to have_ticket_link
    expect(actions).to have_no_create_button

    page.refresh

    expect(actions).to have_ticket_link
  end

  it "lets a creator without viewing permission see completion without the ticket link" do
    group.add(user)
    SiteSetting.zendesk_create_ticket_allowed_groups = group.id.to_s
    sign_in(user)

    topic_page.visit_topic(topic)
    actions.create_ticket

    expect(actions).to have_created_confirmation
    expect(actions).to have_no_ticket_link
    expect(actions).to have_no_create_button

    page.refresh

    expect(actions).to have_created_confirmation
    expect(actions).to have_no_create_button
  end

  it "lets a creator read a long confirmation on mobile", mobile: true do
    group.add(user)
    SiteSetting.zendesk_create_ticket_allowed_groups = group.id.to_s
    TranslationOverride.upsert!(
      "en",
      "js.zendesk.ticket_created",
      "Zendesk support ticket created for the customer escalation #{"A" * 80}",
    )
    topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = "123"
    topic.save_custom_fields
    sign_in(user)

    topic_page.visit_topic(topic)

    expect(actions).to have_created_confirmation
    expect(actions.confirmation_overflows?).to eq(false)
  end

  it "lets a viewer follow an existing ticket without creating tickets" do
    group.add(user)
    SiteSetting.zendesk_view_ticket_allowed_groups = group.id.to_s
    topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = "123"
    topic.save_custom_fields
    sign_in(user)

    topic_page.visit_topic(topic)

    expect(actions).to have_ticket_link
    expect(actions).to have_no_create_button

    topic_page.visit_topic(Fabricate(:post).topic)

    expect(actions).to have_no_ticket_link
    expect(actions).to have_no_create_button
  end

  it "keeps ticket creation available to staff by default" do
    sign_in(Fabricate(:moderator))

    topic_page.visit_topic(topic)
    actions.create_ticket

    expect(actions).to have_ticket_link
  end

  it "lets a creator retry after a failed request" do
    group.add(user)
    SiteSetting.zendesk_create_ticket_allowed_groups = group.id.to_s
    SiteSetting.zendesk_view_ticket_allowed_groups = group.id.to_s
    sign_in(user)
    stub_request(:post, "https://your-url.zendesk.com/api/v2/tickets")
      .to_return(
        status: 422,
        body: { error: "RecordInvalid", description: "Ticket could not be created" }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )
      .then
      .to_return(
        status: 200,
        body: { ticket: { id: 123, url: "ticket-url" } }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

    topic_page.visit_topic(topic)
    actions.create_ticket

    expect(dialog).to be_open
    dialog.click_ok
    actions.create_ticket

    expect(actions).to have_ticket_link
  end

  it "hides ticket actions from users without permission" do
    sign_in(user)

    topic_page.visit_topic(topic)

    expect(topic_page).to have_topic_title(topic.title)
    expect(actions).to have_no_create_button
    expect(actions).to have_no_ticket_link
  end
end
