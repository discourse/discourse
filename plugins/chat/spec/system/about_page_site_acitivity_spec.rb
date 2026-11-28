# frozen_string_literal: true

describe "Chat messages site activity in the about page" do
  let(:about_page) { PageObjects::Pages::About.new }

  fab!(:channel, :chat_channel)
  fab!(:author, :user)

  before do
    chat_system_bootstrap

    [5.hours.ago, 2.days.ago, 6.days.ago, 9.days.ago].each do |created_at|
      Fabricate(:chat_message, chat_channel: channel, user: author, created_at:)
    end
    channel.update_last_message_id!
  end

  it "displays the number of chat messages in the last 7 days" do
    about_page.visit

    expect(about_page.site_activities.custom("chat-messages")).to have_custom_count(
      I18n.t("js.about.activities.chat_messages", count: 3, formatted_number: "3"),
    )
    expect(about_page.site_activities.custom("chat-messages")).to have_custom_period(
      I18n.t("js.about.activities.periods.last_7_days"),
    )
  end
end
