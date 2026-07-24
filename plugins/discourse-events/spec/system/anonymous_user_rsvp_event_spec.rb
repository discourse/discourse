# frozen_string_literal: true

describe "Anonymous user RSVPing to an event" do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, username: "testuser", password: "supersecurepassword") }
  fab!(:topic) { Fabricate(:topic, user: admin) }

  let(:post_event_page) { PageObjects::Pages::DiscourseCalendar::PostEvent.new }
  let(:login_page) { PageObjects::Pages::Login.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:staff]
    EmailToken.confirm(Fabricate(:email_token, user:).token)
    PostCreator.create!(
      admin,
      topic_id: topic.id,
      raw: "[event start='2222-02-22 14:22' status='public']\n[/event]",
    )
  end

  it "automatically saves the RSVP after login" do
    visit(topic.url)

    expect(post_event_page).to have_going_button

    post_event_page.going

    expect(login_page).to be_open

    login_page.fill(username: user.username, password: "supersecurepassword").click_login

    expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
    expect(post_event_page).to have_going_status
  end

  it "overwrites an existing RSVP when an anon clicks a different status and logs in" do
    event = DiscoursePostEvent::Event.find(topic.first_post.id)
    DiscoursePostEvent::Invitee.create_attendance!(user.id, event.id, :not_going)

    visit(topic.url)
    post_event_page.going

    expect(login_page).to be_open
    login_page.fill(username: user.username, password: "supersecurepassword").click_login

    expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
    expect(post_event_page).to have_going_status

    invitee = DiscoursePostEvent::Invitee.find_by(user_id: user.id, post_id: event.id)
    expect(invitee.status).to eq(DiscoursePostEvent::Invitee.statuses[:going])
  end

  context "when the site is invite-only without login required" do
    before do
      SiteSetting.invite_only = true
      SiteSetting.login_required = false
    end

    it "does not show RSVP buttons to anonymous users" do
      visit(topic.url)
      expect(post_event_page).to have_no_going_menu
      expect(page).to have_no_css(".going-button")
    end
  end
end
