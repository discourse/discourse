# frozen_string_literal: true

describe "Wizard" do
  fab!(:admin)

  let(:wizard_page) { PageObjects::Pages::Wizard.new }

  before { sign_in(admin) }

  it "successfully completes the setup wizard" do
    browser_page.goto("/wizard").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    screenshot_marker(label: "wizard")

    expect(wizard_page).to be_on_step("setup")
    wizard_page.fill_field("text", "title", "My Test Site")
    wizard_page.select_dropdown_option("default-locale", "en")
    wizard_page.click_jump_in
    expect(browser_page).to PlaywrightMatchers.have_url("/")
  end

  describe "Setup step" do
    it "lets user configure site settings including member access" do
      wizard_page.go_to_step("setup")
      expect(SiteSetting.login_required).to eq(false)
      expect(SiteSetting.invite_only).to eq(false)
      expect(SiteSetting.must_approve_users).to eq(false)

      expect(wizard_page.privacy_step).to have_selected_choice("login-required", "public")
      expect(wizard_page.privacy_step).to have_selected_choice("invite-only", "sign_up")
      expect(wizard_page.privacy_step).to have_selected_choice("must-approve-users", "no")

      wizard_page.fill_field("text", "title", "My Test Site")
      wizard_page.privacy_step.select_access_option("login-required", "private")
      wizard_page.privacy_step.select_access_option("invite-only", "invite_only")
      wizard_page.privacy_step.select_access_option("must-approve-users", "yes")

      wizard_page.click_jump_in

      expect(SiteSetting.login_required).to eq(true)
      expect(SiteSetting.invite_only).to eq(true)
      expect(SiteSetting.must_approve_users).to eq(true)
    end

    it "redirects to homepage when completed" do
      wizard_page.go_to_step("setup")
      wizard_page.fill_field("text", "title", "My Test Site")
      wizard_page.click_jump_in

      expect(browser_page).to PlaywrightMatchers.have_url("/")
    end

    it "prevents submission when title is empty" do
      wizard_page.go_to_step("setup")
      wizard_page.fill_field("text", "title", "")
      wizard_page.click_jump_in

      expect(wizard_page).to be_on_step("setup")
      expect(
        browser_root.locator(".wizard-container__field.text-title.invalid").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "prevents submission when title is 'Discourse'" do
      wizard_page.go_to_step("setup")
      wizard_page.fill_field("text", "title", "Discourse")
      wizard_page.click_jump_in

      expect(wizard_page).to be_on_step("setup")
      expect(
        browser_root.locator(".wizard-container__field.text-title.invalid").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "allows keyboard navigation of radio inputs" do
      wizard_page.go_to_step("setup")

      radio_field = wizard_page.find_field("radio", "login-required")
      first_radio = radio_field.locator("input[type='radio']").first
      choice_id =
        first_radio.evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "value",
        )

      browser_page.evaluate(
        "function(arguments) { arguments[0].focus() }",
        arg: browser_arguments(first_radio),
      )

      expect(
        radio_field.locator(".wizard-container__radio-choice:focus-within").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_page.evaluate(
          "function(arguments) { return document.activeElement.type }",
          arg: [],
        ),
      ).to eq("radio")

      first_radio.press("Space")
      expect(
        radio_field.locator(
          ".wizard-container__radio-choice[data-choice-id='#{choice_id}'].--selected",
        ).filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "keeps arrow key navigation within same radio group" do
      wizard_page.go_to_step("setup")

      login_required_field = wizard_page.find_field("radio", "login-required")
      private_radio = login_required_field.locator("[data-choice-id='private'] input[type='radio']")

      private_radio.click
      private_radio.press("ArrowRight")

      expect(
        login_required_field.locator("input[type='radio']:focus"),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end
end
