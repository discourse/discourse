# frozen_string_literal: true

RSpec.describe "Chat MessageBus | new channel", type: :system do
  fab!(:current_user, :user)
  fab!(:other_user, :user)

  let(:chat_page) { PageObjects::Pages::Chat.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap(current_user)
    other_user.activate
    other_user.user_option.update!(chat_enabled: true)
    Group.refresh_automatic_group!("trust_level_#{other_user.trust_level}".to_sym)
  end

  it "second user sees new DM channel appear in sidebar" do
    sign_in(other_user)
    visit("/")

    using_session(:sender) do
      sign_in(current_user)
      chat_page.visit_new_message(other_user)
      PageObjects::Pages::ChatChannel.new.send_message("Hello from a new DM!")
    end

    expect(page).to have_css(
      ".sidebar-section[data-section-name='chat-dms'] .sidebar-section-link",
      wait: 10,
    )
  end
end
