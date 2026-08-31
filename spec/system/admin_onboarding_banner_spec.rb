# frozen_string_literal: true

describe "Admin Onboarding Banner" do
  fab!(:admin)

  let(:banner) { PageObjects::Components::AdminOnboardingBanner.new }
  let(:predefined_topics_modal) { PageObjects::Modals::AdminOnboardingPredefinedTopics.new }
  let(:design_wizard_panel) { PageObjects::Components::DesignWizardPanel.new }
  let(:create_invite_modal) { PageObjects::Modals::CreateInvite.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.enable_invite_modal_with_roles = false
    SiteSetting.enable_site_owner_onboarding = true
    SiteSetting.default_theme_id = Theme.foundation_theme.id

    sign_in(admin)
  end

  describe "banner visibility" do
    it "shows the onboarding banner for admin users" do
      visit("/")
      expect(banner).to be_visible
    end

    it "shows all three onboarding steps" do
      visit("/")
      expect(banner.step("select_theme")).to be_present
      expect(banner.step("invite_collaborators")).to be_present
      expect(banner.step("start_posting")).to be_present
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

  describe "start posting step" do
    it "opens composer with selected topic and marks step as complete when topic is created" do
      visit("/")
      expect(banner.step_not_completed?("start_posting")).to eq(true)

      banner.click_step_action("start_posting")
      expect(predefined_topics_modal).to be_open
      expect(predefined_topics_modal.topic_card_count).to eq(4)

      predefined_topics_modal.select_topic(0)

      expect(composer).to be_opened
      expect(composer.composer_input.value).not_to be_empty

      composer.composer_input.set("Testing topic selection")
      composer.create
      expect(page).to have_content("Testing topic selection")

      visit("/")
      expect(banner.step_completed?("start_posting")).to eq(true)
    end

    it "can cancel topic selection without completing step" do
      visit("/")
      banner.click_step_action("start_posting")
      expect(predefined_topics_modal).to be_open

      predefined_topics_modal.cancel

      expect(predefined_topics_modal).to be_closed
      expect(banner.step_not_completed?("start_posting")).to eq(true)
    end
  end

  describe "invite collaborators step" do
    it "marks step as complete after creating invite" do
      visit("/")
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)

      banner.click_step_action("invite_collaborators")

      expect(create_invite_modal).to be_open
      create_invite_modal.save_button.click
      expect(create_invite_modal).to have_copy_button

      create_invite_modal.close

      expect(banner.step_completed?("invite_collaborators")).to eq(true)
    end

    it "does not mark step complete if modal is cancelled" do
      visit("/")
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)
      banner.click_step_action("invite_collaborators")

      expect(create_invite_modal).to be_open
      create_invite_modal.close

      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)
    end
  end

  describe "select theme step" do
    it "opens the design wizard as a sheet" do
      visit("/")
      expect(banner.step_not_completed?("select_theme")).to eq(true)

      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible
      expect(design_wizard_panel).to have_site_sidebar
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

      expect(page).to have_current_path("/?preview_theme_id=#{Theme.horizon_theme.id}")
      expect(design_wizard_panel).to be_visible
      expect(design_wizard_panel).to have_selected_theme(Theme.horizon_theme)
    end

    it "does not mark the step complete when closed without saving" do
      visit("/")
      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible

      design_wizard_panel.next_step
      design_wizard_panel.select_palette("default")
      expect(design_wizard_panel).to have_palette_preview

      design_wizard_panel.close

      expect(design_wizard_panel).to be_hidden
      expect(design_wizard_panel).to have_no_palette_preview
      expect(banner.step_not_completed?("select_theme")).to eq(true)
    end

    it "reflects and turns off palettes members can switch between" do
      horizon = Theme.horizon_theme
      horizon.set_default!
      ColorScheme.where(theme_id: horizon.id).update_all(user_selectable: true)

      visit("/")
      banner.click_step_action("select_theme")
      design_wizard_panel.next_step

      expect(design_wizard_panel).to have_user_selectable_palettes

      design_wizard_panel.toggle_user_selectable_palettes

      expect(design_wizard_panel).to have_no_user_selectable_palettes

      design_wizard_panel.next_step
      design_wizard_panel.save

      expect(banner).to be_visible
      expect(ColorScheme.where(theme_id: horizon.id).pluck(:user_selectable)).to all(eq(false))
    end

    it "reverts a previewed welcome banner when closed without saving" do
      visit("/")
      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible

      design_wizard_panel.next_step
      design_wizard_panel.next_step

      expect(design_wizard_panel).to have_welcome_banner_enabled
      expect(page).to have_css(".welcome-banner")

      design_wizard_panel.toggle_welcome_banner

      expect(design_wizard_panel).to have_no_welcome_banner_enabled
      expect(page).to have_no_css(".welcome-banner")

      design_wizard_panel.close

      expect(design_wizard_panel).to be_hidden
      expect(page).to have_css(".welcome-banner")
      expect(SiteSetting.enable_welcome_banner(theme_id: Theme.find_default.id)).to eq(true)
    end

    it "previews and applies the design choices and marks step complete" do
      visit("/")
      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible

      # picking another theme reloads the page with a theme preview and the
      # wizard resumes in the sheet
      design_wizard_panel.select_theme(Theme.horizon_theme.id)
      expect(page).to have_current_path("/?preview_theme_id=#{Theme.horizon_theme.id}")
      expect(design_wizard_panel).to be_visible

      design_wizard_panel.next_step
      design_wizard_panel.select_palette("royal")
      expect(design_wizard_panel).to have_palette_preview
      design_wizard_panel.toggle_user_selectable_palettes
      design_wizard_panel.select_body_font("lato")

      design_wizard_panel.next_step
      design_wizard_panel.select_homepage("categories")
      design_wizard_panel.select_search_experience("search_icon")

      expect(design_wizard_panel).to have_welcome_banner_enabled
      expect(page).to have_css(".welcome-banner")
      design_wizard_panel.select_welcome_banner_location("below_site_header")
      design_wizard_panel.toggle_welcome_banner
      expect(page).to have_no_css(".welcome-banner")

      design_wizard_panel.save

      # Page reloads after saving; wait for it to complete
      expect(banner).to be_visible
      expect(design_wizard_panel).to be_hidden
      expect(banner.step_completed?("select_theme")).to eq(true)

      expect(SiteSetting.default_theme_id).to eq(Theme.horizon_theme.id)
      horizon = Theme.horizon_theme
      expect(horizon.color_scheme.name).to eq("Royal")
      expect(horizon.color_scheme.user_selectable).to eq(true)
      expect(SiteSetting.base_font).to eq("lato")
      expect(SiteSetting.default_homepage).to eq("categories")
      expect(SiteSetting.desktop_category_page_style).to eq("categories_boxes")
      expect(SiteSetting.enable_welcome_banner(theme_id: horizon.id)).to eq(false)
      expect(SiteSetting.welcome_banner_location).to eq("below_site_header")
      expect(SiteSetting.search_experience(theme_id: horizon.id)).to eq("search_icon")

      # the reload must not cancel the in-flight audit write
      expect(
        UserHistory.where(
          action: UserHistory.actions[:admin_onboarding_step_completed],
          acting_user_id: admin.id,
        ).pluck(:subject),
      ).to eq(["select_theme"])
    end
  end

  describe "completing all steps" do
    it "disables onboarding when select theme is completed last" do
      visit("/")

      banner.click_step_action("start_posting")
      predefined_topics_modal.select_topic(0)
      composer.create
      visit("/")

      expect(banner.step_completed?("start_posting")).to eq(true)

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
        ).to contain_exactly("start_posting", "invite_collaborators", "select_theme")

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
