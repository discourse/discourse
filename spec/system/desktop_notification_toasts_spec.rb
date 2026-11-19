# frozen_string_literal: true

describe "Desktop notification toasts" do
  fab!(:user) { Fabricate(:user, last_seen_at: 1.minute.ago) }
  fab!(:post)

  before do
    SiteSetting.enable_desktop_notification_toasts = true
    user.user_option.update!(show_notification_toasts: true)
  end

  def notify(type, label)
    Notification.create!(
      user:,
      topic: post.topic,
      post_number: post.post_number,
      notification_type: Notification.types.fetch(type),
      data: { display_username: label, topic_title: post.topic.title }.to_json,
      skip_send_email: true,
    )
  end

  it "shows new unread notifications, excludes configured types, and limits the stack" do
    SiteSetting.desktop_notification_toast_max_stack = 1
    SiteSetting.desktop_notification_toast_excluded_types = "liked"
    sign_in(user)
    visit "/latest"

    notify(:mentioned, "first_sender")
    expect(page).to have_css(".desktop-notification-toast", text: "first_sender")

    notify(:liked, "excluded_sender")
    expect(page).to have_css(".unread-notifications", text: "2")
    expect(page).to have_css(".desktop-notification-toast", text: "first_sender")
    expect(page).to have_no_css(".desktop-notification-toast", text: "excluded_sender")

    notify(:mentioned, "second_sender")
    expect(page).to have_css(".desktop-notification-toast", text: "second_sender", count: 1)
    expect(page).to have_no_css(".desktop-notification-toast", text: "first_sender")
    expect(page).to have_no_css(".desktop-notification-toast", text: "excluded_sender")

    within(".desktop-notification-toast") do
      click_button I18n.t("js.notifications.desktop_toast.open")
    end
    expect(page).to have_css("#topic-title", text: post.topic.title)
  end

  it "suppresses the toast during Do Not Disturb" do
    user.do_not_disturb_timings.create!(starts_at: 1.minute.ago, ends_at: 1.hour.from_now)
    sign_in(user)
    visit "/latest"
    expect(page).to have_css(".do-not-disturb-background")

    notify(:mentioned, "quiet_sender")
    user.do_not_disturb_timings.delete_all
    user.publish_do_not_disturb

    expect(page).to have_css(".unread-notifications", text: "1")
    expect(page).to have_no_css(".desktop-notification-toast")
  end
end
