# frozen_string_literal: true

describe "Admin Onboarding Banner" do
  fab!(:admin)
  fab!(:staff_category) { Fabricate(:private_category, name: "Staff", group: Group[:staff]) }
  fab!(:general_category) { Fabricate(:category, name: "General") }

  let(:banner) { PageObjects::Components::AdminOnboardingBanner.new }
  let(:predefined_topics_modal) { PageObjects::Modals::AdminOnboardingPredefinedTopics.new }
  let(:design_wizard_panel) { PageObjects::Components::DesignWizardPanel.new }
  let(:create_invite_modal) { PageObjects::Modals::CreateInvite.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.staff_category_id = staff_category.id
    SiteSetting.general_category_id = general_category.id
    SiteSetting.enable_invite_modal_with_roles = false
    SiteSetting.enable_site_owner_onboarding = true
    SiteSetting.default_theme_id = Theme.foundation_theme.id

    sign_in(admin)
  end

  describe "banner visibility" do
    it "shows the onboarding banner for admin users" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(banner).to be_visible
    end

    it "shows all three onboarding steps" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(banner.step_names).to eq(%w[select_theme start_posting invite_collaborators])
      expect(banner.step("select_theme")).to be_present
      expect(banner.step("invite_collaborators")).to be_present
      expect(banner.step("start_posting")).to be_present
    end

    it "can close the banner prematurely" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
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
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(banner.step_not_completed?("start_posting")).to eq(true)

      banner.click_step_action("start_posting")
      expect(predefined_topics_modal).to be_open
      expect(predefined_topics_modal.topic_card_count).to eq(4)

      predefined_topics_modal.select_topic(0)

      expect(composer).to be_opened
      expect(composer.composer_input.input_value).to eq(
        I18n.t("js.admin_onboarding_banner.start_posting.icebreakers.plan_categories.body"),
      )
      expect(composer.category_chooser).to have_selected_name(staff_category.name)

      composer.composer_input.fill("Testing topic selection")
      composer.create
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern("Testing topic selection"),
        useInnerText: true,
      )

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(banner.step_completed?("start_posting")).to eq(true)

      log =
        UserHistory.find_by!(
          action: UserHistory.actions[:admin_onboarding_step_completed],
          acting_user_id: admin.id,
          subject: "start_posting",
        )
      expect(log.new_value).to eq("plan_categories")
      expect(Topic.last.category_id).to eq(staff_category.id)

      logs = PageObjects::Pages::AdminStaffActionLogs.new
      logs.visit
      logs.show_details(log)
      expect(
        browser_root.locator(".log-details-modal").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Selected option: What categories should we start with?")],
        useInnerText: true,
      )
      expect(
        browser_root.locator(".log-details-modal").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("Option ID: plan_categories")],
        useInnerText: true,
      )
    end

    %w[plan_invites introduce_yourself write_your_own].each do |option|
      it "publishes the #{option} choice in its category and records the original option" do
        category = option == "plan_invites" ? staff_category : general_category
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        banner.click_step_action("start_posting")
        predefined_topics_modal.select_option(option)

        expect(composer).to be_opened
        expect(composer.category_chooser).to have_selected_name(category.name)
        if option == "write_your_own"
          expect(composer).to have_input_title("")
          expect(composer).to have_value("")
        else
          expect(composer).to have_input_title(
            I18n.t("js.admin_onboarding_banner.start_posting.icebreakers.#{option}.title"),
          )
          expect(composer).to have_value(
            I18n.t("js.admin_onboarding_banner.start_posting.icebreakers.#{option}.body"),
          )
        end

        composer.fill_title("A conversation for our community")
        composer.fill_content("A new conversation tailored to our community.")
        composer.create
        expect(browser_content).to PlaywrightMatchers.contain_text(
          browser_text_pattern("A new conversation tailored to our community."),
          useInnerText: true,
        )

        try_until_success do
          log = UserHistory.find_by(acting_user_id: admin.id, subject: "start_posting")
          expect(log&.new_value).to eq(option)
        end
        expect(Topic.last.category_id).to eq(category.id)
      end
    end

    it "does not attribute an unrelated topic to a discarded suggestion" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      banner.click_step_action("start_posting")
      predefined_topics_modal.select_option("plan_categories")
      composer.discard
      PageObjects::Modals::DiscardDraft.new.click_discard
      expect(composer).to be_closed
      expect(banner.step_not_completed?("start_posting")).to eq(true)
      expect(UserHistory.exists?(acting_user_id: admin.id, subject: "start_posting")).to eq(false)

      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      composer.fill_title("An unrelated community conversation")
      composer.fill_content("This topic was not started from an onboarding suggestion.")
      composer.switch_category(general_category.name)
      composer.create
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern("This topic was not started from an onboarding suggestion."),
        useInnerText: true,
      )

      try_until_success do
        log = UserHistory.find_by(acting_user_id: admin.id, subject: "start_posting")
        expect(log).to be_present
        expect(log.new_value).to be_nil
        expect(log.details).to be_nil
      end
    end

    it "retains attribution when a saved draft is resumed after a reload" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      banner.click_step_action("start_posting")
      predefined_topics_modal.select_option("plan_invites")
      composer.close
      expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      drafts_menu = PageObjects::Components::DraftsMenu.new
      drafts_menu.open
      drafts_menu.resume_draft
      expect(composer).to have_input_title(
        I18n.t("js.admin_onboarding_banner.start_posting.icebreakers.plan_invites.title"),
      )
      composer.create
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(
          I18n.t("js.admin_onboarding_banner.start_posting.icebreakers.plan_invites.body"),
        ),
        useInnerText: true,
      )

      try_until_success do
        log = UserHistory.find_by(acting_user_id: admin.id, subject: "start_posting")
        expect(log&.new_value).to eq("plan_invites")
      end
    end

    it "disables Staff suggestions when the configured category is unavailable" do
      SiteSetting.staff_category_id = -1
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      banner.click_step_action("start_posting")
      expect(predefined_topics_modal).to have_disabled_option("plan_categories")
      expect(predefined_topics_modal).to have_disabled_option("plan_invites")
      predefined_topics_modal.select_option("write_your_own")
      expect(composer).to be_opened
      expect(composer.category_chooser).to have_selected_name(general_category.name)
    end

    it "can cancel topic selection without completing step" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      banner.click_step_action("start_posting")
      expect(predefined_topics_modal).to be_open

      predefined_topics_modal.cancel

      expect(predefined_topics_modal).to be_closed
      expect(banner.step_not_completed?("start_posting")).to eq(true)
    end
  end

  describe "invite collaborators step" do
    it "marks step as complete after creating invite" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)

      banner.click_step_action("invite_collaborators")

      expect(create_invite_modal).to be_open
      create_invite_modal.save_button.click
      expect(create_invite_modal).to have_copy_button

      create_invite_modal.close

      expect(banner.step_completed?("invite_collaborators")).to eq(true)
    end

    it "does not mark step complete if modal is cancelled" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)
      banner.click_step_action("invite_collaborators")

      expect(create_invite_modal).to be_open
      create_invite_modal.close

      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)
    end
  end

  describe "select theme step" do
    it "opens the design wizard as a sheet" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(banner.step_not_completed?("select_theme")).to eq(true)

      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible
      expect(design_wizard_panel).to have_site_sidebar
    end

    it "docks to the bottom edge on a narrow viewport, leaving the preview visible" do
      admin.update!(uploaded_avatar: Fabricate(:image_upload, width: 100, height: 100))
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      banner.click_step_action("select_theme")
      expect(design_wizard_panel).to be_visible

      browser_page
        .set_viewport_size({ width: 320, height: 740 })
        .tap { SystemBrowserSynchronization.wait_for_resize(browser_page) }

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

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible
      expect(browser_page).to PlaywrightMatchers.have_url("/")
      expect(design_wizard_panel).to have_no_selected_theme
      expect(design_wizard_panel).to have_disabled_next

      design_wizard_panel.select_theme(Theme.horizon_theme.id)

      expect(browser_page).to PlaywrightMatchers.have_url(
        "/?preview_theme_id=#{Theme.horizon_theme.id}",
      )
      expect(design_wizard_panel).to be_visible
      expect(design_wizard_panel).to have_selected_theme(Theme.horizon_theme)
    end

    it "does not mark the step complete when closed without saving" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
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

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
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
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible

      design_wizard_panel.next_step
      design_wizard_panel.next_step

      expect(design_wizard_panel).to have_welcome_banner_enabled
      expect(
        browser_root.locator(".welcome-banner").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      design_wizard_panel.toggle_welcome_banner

      expect(design_wizard_panel).to have_no_welcome_banner_enabled
      expect(
        browser_root.locator(".welcome-banner").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)

      design_wizard_panel.close

      expect(design_wizard_panel).to be_hidden
      expect(
        browser_root.locator(".welcome-banner").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(SiteSetting.enable_welcome_banner(theme_id: Theme.find_default.id)).to eq(true)
    end

    it "previews and applies the design choices and marks step complete" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      banner.click_step_action("select_theme")

      expect(design_wizard_panel).to be_visible

      # picking another theme reloads the page with a theme preview and the
      # wizard resumes in the sheet
      design_wizard_panel.select_theme(Theme.horizon_theme.id)
      expect(browser_page).to PlaywrightMatchers.have_url(
        "/?preview_theme_id=#{Theme.horizon_theme.id}",
      )
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
      expect(
        browser_root.locator(".welcome-banner").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      design_wizard_panel.select_welcome_banner_location("below_site_header")
      design_wizard_panel.toggle_welcome_banner
      expect(
        browser_root.locator(".welcome-banner").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)

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
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      banner.click_step_action("start_posting")
      predefined_topics_modal.select_topic(0)
      composer.create
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(banner).to be_not_visible
    end
  end

  describe "when setting is disabled" do
    before { SiteSetting.enable_site_owner_onboarding = false }

    it "does not show the banner" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(banner).to be_not_visible
    end
  end
end
