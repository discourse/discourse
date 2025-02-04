# frozen_string_literal: true

describe "Chat messages site activity in the about page", type: :system do
  let(:about_page) { PageObjects::Pages::About.new }

  before do
    chat_system_bootstrap

    Fabricate(:chat_message, created_at: 5.hours.ago)
    Fabricate(:chat_message, created_at: 2.days.ago)
    Fabricate(:chat_message, created_at: 6.days.ago)
    Fabricate(:chat_message, created_at: 9.days.ago)
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
