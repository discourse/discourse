# frozen_string_literal: true

RSpec.describe "Viewing another user's chat preferences" do
  fab!(:moderator)
  fab!(:user)

  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:user_preferences_chat_page) { PageObjects::Pages::UserPreferencesChat.new }

  before { chat_system_bootstrap }

  it "lets a moderator disable the user's chat without reloading the page" do
    sign_in(moderator)
    user_preferences_chat_page.open_from_preferences_nav(user)

    expect(page).to have_current_path("/u/#{user.username}/preferences/chat")

    page.execute_script(
      "window.addEventListener('beforeunload', () => sessionStorage.setItem('reloaded', '1'))",
    )

    form.field("chat_enabled").uncheck
    form.submit

    expect(user_preferences_chat_page).to have_saved
    expect(page.evaluate_script("sessionStorage.getItem('reloaded') === null")).to eq(true)

    page.refresh

    expect(form.field("chat_enabled")).to be_unchecked
  end
end
