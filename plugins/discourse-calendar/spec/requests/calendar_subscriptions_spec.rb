# frozen_string_literal: true

describe "Calendar subscription feeds" do
  fab!(:user)

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  it "includes event feeds when calendar plugin is enabled" do
    sign_in(user)
    post "/calendar-subscriptions.json"
    expect(response.status).to eq(200)

    body = response.parsed_body
    expect(body["urls"]["all_events"]).to include("/discourse-post-event/events.ics")
    expect(body["urls"]["my_events"]).to include("attending_user=#{user.username_lower}")
    expect(body["urls"]["my_events"]).to include("include_interested=true")
    expect(body["urls"]["bookmarks"]).to include("/u/#{user.username_lower}/bookmarks.ics")
  end

  it "includes the events_calendar scope on the key" do
    sign_in(user)
    post "/calendar-subscriptions.json"

    api_key =
      UserApiKey.joins(:client).find_by(
        user_id: user.id,
        user_api_key_clients: {
          client_id: CalendarSubscriptionsController::CLIENT_ID,
        },
      )
    expect(api_key.scopes.map(&:name)).to contain_exactly(
      "discourse-calendar:events_calendar",
      "bookmarks_calendar",
    )
  end

  it "lists all available feeds" do
    sign_in(user)
    get "/calendar-subscriptions.json"

    expect(response.parsed_body["feeds"]).to contain_exactly("bookmarks", "all_events", "my_events")
  end
end
