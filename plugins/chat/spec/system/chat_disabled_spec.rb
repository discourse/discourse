# frozen_string_literal: true

RSpec.describe "Chat | disabled in preferences" do
  include ThemeScreenshotMarker

  fab!(:current_user, :user)
  fab!(:inviter, :user)
  fab!(:channel_1, :category_channel)
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: inviter) }

  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before do
    chat_system_bootstrap(current_user, [channel_1])
    current_user.user_option.update!(chat_enabled: false)

    current_user.notifications.create!(
      notification_type: Notification.types[:chat_invitation],
      high_priority: true,
      read: false,
      data: {
        chat_channel_id: channel_1.id,
        chat_channel_title: channel_1.title(current_user),
        chat_channel_slug: channel_1.slug,
        invited_by_username: inviter.username,
        chat_message_id: message_1.id,
      }.to_json,
    )

    current_user.notifications.create!(
      notification_type: Notification.types[:chat_mention],
      high_priority: true,
      read: false,
      data: {
        chat_message_id: message_1.id,
        chat_channel_id: channel_1.id,
        mentioned_by_username: inviter.username,
        is_direct_message_channel: false,
        chat_channel_title: channel_1.title(current_user),
        chat_channel_slug: channel_1.slug,
      }.to_json,
    )

    sign_in(current_user)
  end

  it "still renders chat notifications in the user menu" do
    visit "/"
    user_menu.open

    expect(page).to have_css(
      ".user-menu .notification.chat-invitation .item-label",
      text: inviter.username,
    )
    screenshot_marker(label: "chatdisabled-notifications", only: :desktop)
  end

  it "shows the disabled page instead of redirecting home" do
    visit "/chat/disabled"

    expect(page).to have_css(".chat-disabled .empty-state__title")
    screenshot_marker(label: "chatdisabled-page", only: :desktop)
  end
end
