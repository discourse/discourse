# frozen_string_literal: true

RSpec.describe "Open chat during the design wizard" do
  fab!(:admin)
  fab!(:assistant) { Fabricate(:user, username: "admin_assistant", name: "Admin Assistant") }
  fab!(:channel) { Fabricate(:direct_message_channel, users: [admin, assistant]) }

  let(:banner) { PageObjects::Components::AdminOnboardingBanner.new }
  let(:design_wizard) { PageObjects::Components::DesignWizardPanel.new }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_sidebar) { PageObjects::Pages::ChatSidebar.new }
  let(:chat_channel) { PageObjects::Pages::ChatChannel.new }
  let(:chat_drawer) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap(admin)
    SiteSetting.enable_site_owner_onboarding = true
    SiteSetting.default_theme_id = Theme.foundation_theme.id
    sign_in(admin)
    chat_page.prefers_drawer
  end

  it "lets an admin chat from the sidebar and resume their design choices" do
    visit("/")
    banner.click_step_action("select_theme")
    expect(design_wizard).to have_selected_theme(Theme.foundation_theme)

    [992, 1440].each do |width|
      page.current_window.resize_to(width, 1000)

      chat_sidebar.open_channel(channel)

      expect(design_wizard).to be_minimized
      expect(chat_drawer).to have_open_channel(channel)

      chat_channel.type_in_composer("Help me customize my community")
      expect(chat_channel.composer).to be_focused

      chat_drawer.close
      design_wizard.restore

      expect(design_wizard).to have_step("theme")
      expect(design_wizard).to have_selected_theme(Theme.foundation_theme)
    end
  end
end
