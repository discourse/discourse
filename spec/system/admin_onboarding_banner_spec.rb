# frozen_string_literal: true

describe "Admin Onboarding Banner" do
  fab!(:admin)
  fab!(:general_category) { Fabricate(:category, name: "General") }

  let(:banner) { PageObjects::Components::AdminOnboardingBanner.new }
  let(:design_wizard_panel) { PageObjects::Components::DesignWizardPanel.new }
  let(:create_invite_modal) { PageObjects::Modals::CreateInvite.new }
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:category_form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:category_type_card) { PageObjects::Components::CategoryTypeCard.new }
  let(:cdp) { PageObjects::CDP.new }

  # plugins can register more category types, which adds a type step first
  def open_category_form_from_banner
    banner.click_step_action("create_category")
    expect(page).to have_current_path(%r{\A/new-category/(setup|general)\z})
    if page.current_path == "/new-category/setup"
      category_type_card.find_type_card("discussion").click
    end
    expect(page).to have_current_path("/new-category/general")
  end

  before do
    SiteSetting.enable_invite_modal_with_roles = false
    SiteSetting.enable_site_owner_onboarding = true
    SiteSetting.default_theme_id = Theme.foundation_theme.id

    sign_in(admin)
  end

  describe "banner visibility" do
    it "shows the onboarding banner with all three steps for admin users" do
      visit("/")
      expect(banner).to be_visible
      expect(banner.step_names).to eq(%w[select_theme create_category invite_collaborators])
    end

    it "can close the banner prematurely" do
      visit("/")
      expect(banner).to be_visible

      banner.close

      expect(SiteSetting.enable_site_owner_onboarding).to eq(false)
      try_until_success do
        expect(
          UserHistory.exists?(
            action: UserHistory.actions[:admin_onboarding_dismissed],
            acting_user_id: admin.id,
          ),
        ).to eq(true)
      end
    end
  end

  describe "create category step" do
    def create_category_step_logged?
      UserHistory.exists?(
        action: UserHistory.actions[:admin_onboarding_step_completed],
        acting_user_id: admin.id,
        subject: "create_category",
      )
    end

    it "only completes the step after the admin saves a new category" do
      visit("/")
      expect(banner.step_not_completed?("create_category")).to eq(true)

      open_category_form_from_banner

      visit("/")
      expect(banner.step_not_completed?("create_category")).to eq(true)

      open_category_form_from_banner

      category_form.field("name").fill_in("Announcements")
      category_page.save_settings
      expect(page).to have_current_path(%r{\A/c/announcements/\d+\z})

      try_until_success { expect(create_category_step_logged?).to eq(true) }

      visit("/")
      expect(banner.step_completed?("create_category")).to eq(true)
    end

    it "stays open when an existing category is edited" do
      category_page.visit_general(general_category)
      category_form.field("name").fill_in("General chat")
      category_page.save_settings
      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.saved"))

      visit("/")
      expect(banner.step_not_completed?("create_category")).to eq(true)
      expect(create_category_step_logged?).to eq(false)
    end
  end

  describe "invite collaborators step" do
    it "only completes the step after the admin creates an invite" do
      visit("/")
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)

      banner.click_step_action("invite_collaborators")
      expect(create_invite_modal).to be_open
      create_invite_modal.close
      expect(create_invite_modal).to be_closed
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)

      banner.click_step_action("invite_collaborators")
      expect(create_invite_modal).to be_open
      create_invite_modal.save_button.click
      expect(create_invite_modal).to have_copy_button

      create_invite_modal.close

      expect(banner.step_completed?("invite_collaborators")).to eq(true)
    end
  end

  describe "select theme step" do
    let(:dark_only_palette) do
      ColorScheme.create_from_base(
        name: "Midnight",
        base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"],
      )
    end

    it "docks to the bottom edge on a narrow viewport, leaving the preview visible" do
      admin.update!(uploaded_avatar: Fabricate(:image_upload, width: 100, height: 100))
      visit("/")

      banner.click_step_action("select_theme")
      expect(design_wizard_panel).to be_visible

      page.current_window.resize_to(320, 740)

      dimensions = design_wizard_panel.layout_dimensions

      expect(dimensions[:panel_width]).to be <= dimensions[:viewport_width]
      expect(dimensions[:document_scroll_width]).to be <= dimensions[:viewport_width]

      # a full-height rail would hide the page it previews
      expect(dimensions[:panel_bottom]).to be_within(1).of(dimensions[:viewport_height])
      expect(dimensions[:panel_top]).to be > dimensions[:viewport_height] * 0.25
    end

    it "keeps a custom default theme rendered until another theme is chosen" do
      custom_theme = Fabricate(:theme)
      custom_theme.set_default!

      visit("/")
      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible
      expect(page).to have_current_path("/")
      expect(design_wizard_panel).to have_no_selected_theme
      expect(design_wizard_panel).to have_disabled_next

      design_wizard_panel.select_theme(Theme.horizon_theme.id)

      expect(page).to have_current_path("/latest?preview_theme_id=#{Theme.horizon_theme.id}")
      expect(design_wizard_panel).to be_visible
      expect(design_wizard_panel).to have_selected_theme(Theme.horizon_theme)
    end

    it "opens the design wizard as a sheet and leaves the step incomplete on close" do
      visit("/")
      expect(banner.step_not_completed?("select_theme")).to eq(true)

      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible
      expect(design_wizard_panel).to have_site_sidebar

      design_wizard_panel.next_step
      design_wizard_panel.select_palette("default")
      expect(design_wizard_panel).to have_palette_preview

      design_wizard_panel.close

      expect(design_wizard_panel).to be_hidden
      expect(design_wizard_panel).to have_no_palette_preview
      expect(banner.step_not_completed?("select_theme")).to eq(true)
    end

    it "saves a light only site" do
      dark_only_palette
      visit("/")
      banner.click_step_action("select_theme")
      design_wizard_panel.next_step

      expect(design_wizard_panel).to have_palette_mode("both")
      expect(design_wizard_panel).to have_selected_palette("default")

      design_wizard_panel.select_palette_mode("dark")
      expect(design_wizard_panel).to have_palette("custom_#{dark_only_palette.id}")

      design_wizard_panel.select_palette_mode("light")
      expect(design_wizard_panel).to have_no_palette("custom_#{dark_only_palette.id}")

      design_wizard_panel.select_palette("solarized")
      design_wizard_panel.next_step
      design_wizard_panel.save

      expect(banner).to be_visible
      theme = Theme.find_default
      expect(theme.color_scheme.base_scheme_id).to eq(
        ColorScheme::NAMES_TO_ID_MAP["Solarized Light"],
      )
      expect(theme.dark_color_scheme_id).to be_nil
    end

    it "saves the dark palette for both modes on a dark only site" do
      visit("/")
      banner.click_step_action("select_theme")
      design_wizard_panel.next_step

      design_wizard_panel.select_palette_mode("dark")
      design_wizard_panel.select_palette("dracula")
      design_wizard_panel.next_step
      design_wizard_panel.save

      expect(banner).to be_visible
      theme = Theme.find_default
      dracula_id = ColorScheme::NAMES_TO_ID_MAP["Dracula"]
      expect(theme.color_scheme.base_scheme_id).to eq(dracula_id)
      expect(theme.dark_color_scheme.base_scheme_id).to eq(dracula_id)
    end

    it "saves both palettes of the pair picked for light and dark" do
      dark_only_palette
      visit("/")
      banner.click_step_action("select_theme")
      design_wizard_panel.next_step

      expect(design_wizard_panel).to have_palette("dracula")
      expect(design_wizard_panel).to have_no_palette("custom_#{dark_only_palette.id}")

      design_wizard_panel.select_palette("solarized")
      design_wizard_panel.next_step
      design_wizard_panel.save

      expect(banner).to be_visible
      theme = Theme.find_default
      expect(theme.color_scheme.base_scheme_id).to eq(
        ColorScheme::NAMES_TO_ID_MAP["Solarized Light"],
      )
      expect(theme.dark_color_scheme.base_scheme_id).to eq(
        ColorScheme::NAMES_TO_ID_MAP["Solarized Dark"],
      )
    end

    it "offers palettes admins created only in the mode their colors suit" do
      night =
        ColorScheme.create_from_base(
          name: "Night",
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"],
        )

      visit("/")
      banner.click_step_action("select_theme")
      design_wizard_panel.next_step

      expect(design_wizard_panel).to have_no_palette("custom_#{night.id}")

      design_wizard_panel.select_palette_mode("light")

      expect(design_wizard_panel).to have_no_palette("custom_#{night.id}")

      design_wizard_panel.select_palette_mode("dark")
      design_wizard_panel.select_palette("custom_#{night.id}")

      expect(design_wizard_panel).to have_selected_palette("custom_#{night.id}")

      design_wizard_panel.next_step
      design_wizard_panel.save

      expect(banner).to be_visible
      expect(Theme.find_default.dark_color_scheme_id).to eq(night.id)
    end

    it "keeps palettes members can switch between" do
      horizon = Theme.horizon_theme
      horizon.set_default!
      ColorScheme.where(theme_id: horizon.id).update_all(user_selectable: true)

      visit("/")
      banner.click_step_action("select_theme")
      design_wizard_panel.next_step
      design_wizard_panel.next_step
      design_wizard_panel.save

      expect(banner).to be_visible
      expect(ColorScheme.where(theme_id: horizon.id).pluck(:user_selectable)).to all(eq(true))
    end

    it "previews and applies the design choices and marks step complete" do
      SiteSetting.desktop_category_page_style = "categories_and_latest_topics"
      visit("/")
      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible

      # picking another theme reloads the page with a theme preview and the
      # wizard resumes in the sheet
      design_wizard_panel.select_theme(Theme.horizon_theme.id)
      expect(page).to have_current_path("/latest?preview_theme_id=#{Theme.horizon_theme.id}")
      expect(design_wizard_panel).to be_visible

      design_wizard_panel.next_step
      design_wizard_panel.select_palette("royal")
      expect(design_wizard_panel).to have_palette_preview

      design_wizard_panel.next_step
      design_wizard_panel.select_body_font("lato")
      design_wizard_panel.select_homepage("categories")
      design_wizard_panel.save

      # Page reloads after saving; wait for it to complete
      expect(banner).to be_visible
      expect(design_wizard_panel).to be_hidden
      expect(banner.step_completed?("select_theme")).to eq(true)

      expect(SiteSetting.default_theme_id).to eq(Theme.horizon_theme.id)
      horizon = Theme.horizon_theme
      expect(horizon.color_scheme.name).to eq("Royal")
      expect(SiteSetting.base_font).to eq("lato")
      expect(SiteSetting.default_homepage).to eq("categories")
      expect(SiteSetting.desktop_category_page_style).to eq("categories_boxes")

      # the reload must not cancel the in-flight audit write
      expect(
        UserHistory.where(
          action: UserHistory.actions[:admin_onboarding_step_completed],
          acting_user_id: admin.id,
        ).pluck(:subject),
      ).to eq(["select_theme"])
    end
  end

  describe "AI agent tab" do
    it "starts on the step by step tab" do
      visit("/")

      expect(banner.tab("Step by step")["aria-selected"]).to eq("true")
      expect(banner.step_names).to eq(%w[select_theme create_category invite_collaborators])
    end

    it "gives the admin a prompt that points their agent at this site" do
      cdp.allow_clipboard
      visit("/")

      banner.tab("With an AI agent").click
      expect(banner.agent_panel).to have_css(
        ".admin-onboarding-agent__prompt-text",
        text: "#{Discourse.base_url}/mcp",
      )

      banner.agent_panel.find(".admin-onboarding-agent__copy-prompt").click

      cdp.clipboard_has_text?(
        I18n.t(
          "js.admin_onboarding_banner.agent.prompt",
          site_url: Discourse.base_url,
          mcp_url: "#{Discourse.base_url}/mcp",
          instructions_url: "#{Discourse.base_url}/agent-setup.md",
        ),
      )
    end

    it "can be hidden for good" do
      visit("/")

      banner.tab("With an AI agent").click
      banner.agent_panel.find(".admin-onboarding-agent__hide").click

      expect(banner).to have_no_tabs
      expect(banner.step_names).to eq(%w[select_theme create_category invite_collaborators])

      visit("/")
      expect(banner).to be_visible
      expect(banner).to have_no_tabs
    end

    it "shows when an agent has connected and folds the prompt away" do
      StaffActionLogger.new(admin).log_admin_onboarding_step_completed("connect_agent")

      visit("/")
      banner.tab("With an AI agent").click

      expect(banner.agent_panel).to have_css(
        ".admin-onboarding-agent__connected",
        text: I18n.t("js.admin_onboarding_banner.agent.connected"),
      )
      expect(banner.agent_panel).to have_no_css(".admin-onboarding-agent__prompt")

      banner.agent_panel.find(".admin-onboarding-agent__toggle-prompt").click

      expect(banner.agent_panel).to have_css(
        ".admin-onboarding-agent__prompt-text",
        text: "#{Discourse.base_url}/mcp",
      )
    end

    it "links to where the admin can disconnect agents" do
      client =
        McpOauthClient.create!(
          client_id: "onboarding-agent",
          name: "Onboarding agent",
          registration_type: "pre_registered",
          trust_state: "approved",
          redirect_uris: ["http://127.0.0.1/callback"],
        )
      McpOauthAuthorization.create!(
        user: admin,
        client:,
        resource: DiscourseMcp.resource_url,
        consented_at: Time.zone.now,
        status: "active",
      )

      visit("/")
      banner.tab("With an AI agent").click
      banner.agent_panel.find(".admin-onboarding-agent__note a").click

      expect(page).to have_current_path("/u/#{admin.username}/preferences/security")
      expect(page).to have_css(".user-mcp-authorizations", text: "Onboarding agent")
    end

    it "isn't offered when the MCP server is disabled" do
      SiteSetting.mcp_server_enabled = false

      visit("/")

      expect(banner).to be_visible
      expect(banner).to have_no_tabs
    end
  end

  describe "steps completed away from the banner" do
    def log_steps(*steps)
      steps.each { |step| StaffActionLogger.new(admin).log_admin_onboarding_step_completed(step) }
    end

    def onboarding_completed_logged?
      UserHistory.exists?(
        action: UserHistory.actions[:admin_onboarding_completed],
        acting_user_id: admin.id,
      )
    end

    it "ticks a step the admin's AI agent completes while the banner is open" do
      visit("/")
      expect(banner.step_not_completed?("create_category")).to eq(true)

      CategoryCreator.create(admin.guardian, name: "Made by an agent")

      expect(banner.step_completed?("create_category")).to eq(true)
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)
    end

    it "finishes onboarding when the agent completes the last step" do
      log_steps("select_theme", "invite_collaborators")
      visit("/")
      expect(banner).to be_visible

      CategoryCreator.create(admin.guardian, name: "Made by an agent")

      expect(banner).to be_not_visible
      expect(PageObjects::Components::Toasts.new).to have_success(
        I18n.t("js.admin_onboarding_banner.congrats_onboarding_complete"),
      )
      try_until_success do
        expect(SiteSetting.enable_site_owner_onboarding).to eq(false)
        expect(onboarding_completed_logged?).to eq(true)
      end
    end

    it "finishes onboarding on the next visit when every step was done elsewhere" do
      log_steps("select_theme", "create_category", "invite_collaborators")

      visit("/")

      expect(banner).to be_not_visible
      try_until_success { expect(onboarding_completed_logged?).to eq(true) }
    end
  end

  describe "completing all steps" do
    it "disables onboarding when select theme is completed last" do
      visit("/")

      open_category_form_from_banner
      category_form.field("name").fill_in("Announcements")
      category_page.save_settings
      expect(page).to have_current_path(%r{\A/c/announcements/\d+\z})
      visit("/")

      expect(banner.step_completed?("create_category")).to eq(true)

      banner.click_step_action("invite_collaborators")
      create_invite_modal.save_button.click
      expect(create_invite_modal).to have_copy_button
      create_invite_modal.close

      expect(banner.step_completed?("invite_collaborators")).to eq(true)

      banner.click_step_action("select_theme")
      expect(design_wizard_panel).to be_visible
      design_wizard_panel.next_step
      design_wizard_panel.next_step
      design_wizard_panel.save

      # Page reloads after saving; banner disappears when all steps complete
      expect(banner).to be_not_visible
      expect(SiteSetting.enable_site_owner_onboarding).to eq(false)

      try_until_success do
        expect(
          UserHistory.where(
            action: UserHistory.actions[:admin_onboarding_step_completed],
            acting_user_id: admin.id,
          ).pluck(:subject),
        ).to contain_exactly("create_category", "invite_collaborators", "select_theme")

        expect(
          UserHistory.exists?(
            action: UserHistory.actions[:admin_onboarding_completed],
            acting_user_id: admin.id,
          ),
        ).to eq(true)
      end
    end
  end

  describe "when user is not an admin" do
    fab!(:regular_user, :user)

    it "does not show the banner" do
      sign_in(regular_user)
      visit("/")

      expect(banner).to be_not_visible
    end
  end

  describe "when setting is disabled" do
    before { SiteSetting.enable_site_owner_onboarding = false }

    it "does not show the banner" do
      visit("/")

      expect(banner).to be_not_visible
    end
  end
end
