# frozen_string_literal: true

RSpec.describe "Drawer with the design wizard" do
  fab!(:admin)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:design_wizard_panel) { PageObjects::Components::DesignWizardPanel.new }
  let(:onboarding_banner) { PageObjects::Components::AdminOnboardingBanner.new }

  before do
    SiteSetting.default_theme_id = Theme.foundation_theme.id
    chat_system_bootstrap
    sign_in(admin)
    chat_page.prefers_drawer
  end

  def drawer_right
    page.evaluate_script(<<~JS)
      document.querySelector(".chat-drawer").getBoundingClientRect().right
    JS
  end

  def wizard_left
    page.evaluate_script(<<~JS)
      document.querySelector(".design-wizard").getBoundingClientRect().left
    JS
  end

  it "opens the drawer beside the docked wizard rather than under it" do
    resize_window(width: 1400) do
      visit("/?design_wizard=1")
      expect(page).to have_css("html.design-wizard-docked")

      chat_page.open_from_header
      expect(page).to have_css(".chat-drawer")

      expect(drawer_right).to be <= wizard_left
    end
  end

  it "opens the drawer beside the floating wizard rather than under it" do
    resize_window(width: 1000) do
      visit("/?design_wizard=1")
      expect(page).to have_css("html.design-wizard-floating")

      chat_page.open_from_header
      expect(page).to have_css(".chat-drawer")

      expect(drawer_right).to be <= wizard_left
    end
  end

  it "moves an open drawer aside when the floating wizard opens" do
    SiteSetting.enable_site_owner_onboarding = true

    resize_window(width: 1000) do
      visit("/")
      chat_page.open_from_header
      expect(page).to have_css(".chat-drawer")

      onboarding_banner.click_step_action("select_theme")
      expect(design_wizard_panel).to be_visible

      try_until_success { expect(drawer_right).to be <= wizard_left }
    end
  end
end
