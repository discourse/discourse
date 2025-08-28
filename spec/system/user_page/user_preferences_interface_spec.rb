# frozen_string_literal: true

describe "User preferences | Interface", type: :system do
  fab!(:user)
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }
  let(:user_preferences_interface_page) { PageObjects::Pages::UserPreferencesInterface.new }

  before { sign_in(user) }

  describe "Bookmarks" do
    it "changes the bookmark after notification preference" do
      user_preferences_page.visit(user)
      click_link(I18n.t("js.user.preferences_nav.interface"))

      dropdown = PageObjects::Components::SelectKit.new("#bookmark-after-notification-mode")

      # preselects the default user_option.bookmark_auto_delete_preference value of 3 (clear_reminder)
      expect(dropdown).to have_selected_value(Bookmark.auto_delete_preferences[:clear_reminder])

      dropdown.select_row_by_value(Bookmark.auto_delete_preferences[:when_reminder_sent])
      click_button(I18n.t("js.save"))

      # the preference page reloads after saving, so we need to poll the db
      try_until_success(timeout: 20) do
        expect(
          UserOption.exists?(
            user_id: user.id,
            bookmark_auto_delete_preference: Bookmark.auto_delete_preferences[:when_reminder_sent],
          ),
        ).to be_truthy
      end
    end
  end

  describe "Default Home Page" do
    context "when a user has picked a home page that is no longer available in top_menu" do
      it "shows the selected homepage" do
        SiteSetting.top_menu = "latest|hot"

        user.user_option.update!(homepage_id: UserOption::HOMEPAGES.key("unread"))
        user_preferences_page.visit(user)
        click_link(I18n.t("js.user.preferences_nav.interface"))

        dropdown = PageObjects::Components::SelectKit.new("#home-selector")

        expect(dropdown).to have_selected_name("Unread")
      end
    end

    it "shows only the available home pages from top_menu" do
      SiteSetting.top_menu = "latest|hot"

      user_preferences_page.visit(user)
      click_link(I18n.t("js.user.preferences_nav.interface"))

      dropdown = PageObjects::Components::SelectKit.new("#home-selector")
      dropdown.expand
      expect(dropdown).to have_option_value(UserOption::HOMEPAGES.key("latest"))
      expect(dropdown).to have_option_value(UserOption::HOMEPAGES.key("hot"))
      expect(dropdown).to have_no_option_value(UserOption::HOMEPAGES.key("top"))
      expect(dropdown).to have_no_option_value(UserOption::HOMEPAGES.key("new"))
    end
  end

  describe "Color palette" do
    context "when there's only 1 dark color palette" do
      before do
        dark = ColorScheme.find_by(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"])
        ColorScheme.where.not(id: dark.id).destroy_all
        dark.update!(user_selectable: false)
        user.user_option.update!(dark_scheme_id: dark.id, theme_ids: [SiteSetting.default_theme_id])
      end

      it "always display a mode selector when schemes selectors are available" do
        user_preferences_interface_page.visit(user)
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_value(
          UserOption::AUTO_MODE,
        ),
        "the default value should be auto mode"
      end
    end
  end

  describe "the color mode selector" do
    let(:interface_color_mode) { PageObjects::Components::InterfaceColorMode.new }
    let(:mode_selector_in_sidebar) do
      PageObjects::Components::InterfaceColorSelector.new(".sidebar-footer-actions")
    end

    before { SiteSetting.interface_color_selector = "sidebar_footer" }

    context "when changing own preferences" do
      fab!(:color_scheme_light_1) do
        Fabricate(:color_scheme, base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Light"])
      end
      fab!(:color_scheme_dark_1) do
        Fabricate(:color_scheme, base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"])
      end
      fab!(:color_scheme_light_2) do
        Fabricate(:color_scheme, base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Light"])
      end
      fab!(:color_scheme_dark_2) do
        Fabricate(:color_scheme, base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"])
      end
      fab!(:color_scheme_light_3) do
        Fabricate(
          :color_scheme,
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Light"],
          user_selectable: true,
        )
      end
      fab!(:color_scheme_dark_3) do
        Fabricate(
          :color_scheme,
          base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"],
          user_selectable: true,
        )
      end

      before do
        Theme.find_default.update!(
          color_scheme: color_scheme_light_1,
          dark_color_scheme: color_scheme_dark_1,
        )
      end

      it "has and can change default color scheme for light and dark" do
        user_preferences_interface_page.visit(user)

        expect(user_preferences_interface_page.light_scheme_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.default_description"),
        )
        expect(user_preferences_interface_page.light_scheme_dropdown).to have_selected_value(-1)
        expect(user_preferences_interface_page.dark_scheme_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.default_description"),
        )
        expect(user_preferences_interface_page.dark_scheme_dropdown).to have_selected_value(-1)
        expect(user_preferences_interface_page).to have_light_scheme_css(color_scheme_light_1)
        expect(user_preferences_interface_page).to have_dark_scheme_css(color_scheme_dark_1)

        Theme.find_default.update!(
          color_scheme: color_scheme_light_2,
          dark_color_scheme: color_scheme_dark_2,
        )
        user_preferences_interface_page.visit(user)

        expect(user_preferences_interface_page.light_scheme_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.default_description"),
        )
        expect(user_preferences_interface_page.light_scheme_dropdown).to have_selected_value(-1)
        expect(user_preferences_interface_page.dark_scheme_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.default_description"),
        )
        expect(user_preferences_interface_page.dark_scheme_dropdown).to have_selected_value(-1)
        expect(user_preferences_interface_page).to have_light_scheme_css(color_scheme_light_2)
        expect(user_preferences_interface_page).to have_dark_scheme_css(color_scheme_dark_2)

        user_preferences_interface_page.light_scheme_dropdown.expand
        user_preferences_interface_page.light_scheme_dropdown.select_row_by_value(
          color_scheme_light_3.id,
        )
        user_preferences_interface_page.dark_scheme_dropdown.expand
        user_preferences_interface_page.dark_scheme_dropdown.select_row_by_value(
          color_scheme_dark_3.id,
        )
        user_preferences_interface_page.save_changes

        user_preferences_interface_page.visit(user)

        expect(user_preferences_interface_page.light_scheme_dropdown).to have_selected_name(
          color_scheme_light_3.name,
        )
        expect(user_preferences_interface_page.dark_scheme_dropdown).to have_selected_name(
          color_scheme_dark_3.name,
        )
        expect(user_preferences_interface_page).to have_light_scheme_css(color_scheme_light_3)
        expect(user_preferences_interface_page).to have_dark_scheme_css(color_scheme_dark_3)
      end

      it "can change the color mode for the current device only" do
        user_preferences_interface_page.visit(user)

        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_value(
          UserOption::AUTO_MODE,
        ),
        "the default value should be auto mode"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.interface_modes.auto"),
        ),
        "the default value should be auto mode"

        user_preferences_interface_page.color_mode_dropdown.expand
        user_preferences_interface_page.color_mode_dropdown.select_row_by_value(
          UserOption::DARK_MODE,
        )

        user_preferences_interface_page.default_palette_and_mode_for_all_devices_checkbox.click
        expect do user_preferences_interface_page.save_changes end.to not_change {
          user.user_option.reload.interface_color_mode
        }
        expect(user.user_option.interface_color_mode).to eq(UserOption::AUTO_MODE),
        "the user option in the database doesn't change"

        expect(interface_color_mode).to have_dark_mode_forced, "the interface switches to dark mode"
        expect(mode_selector_in_sidebar).to have_dark_as_current_mode,
        "the selector in the sidebar should show dark mode as selected"

        page.refresh

        expect(interface_color_mode).to have_dark_mode_forced,
        "the interface should still be in dark mode after a page refresh"
        expect(mode_selector_in_sidebar).to have_dark_as_current_mode,
        "the selector in the sidebar should still show dark mode as selected"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_value(
          UserOption::DARK_MODE,
        ),
        "the dropdown should still have dark mode selected after a page refresh"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.interface_modes.dark"),
        ),
        "the dropdown should still have dark mode selected after a page refresh"
      end

      it "can change the default color mode for all devices" do
        user.user_option.update!(interface_color_mode: UserOption::LIGHT_MODE)
        user_preferences_interface_page.visit(user)

        expect(interface_color_mode).to have_light_mode_forced,
        "the interface should be in light mode"
        user_preferences_interface_page.color_mode_dropdown.expand
        user_preferences_interface_page.color_mode_dropdown.select_row_by_value(
          UserOption::DARK_MODE,
        )

        expect do user_preferences_interface_page.save_changes end.to change {
          user.user_option.reload.interface_color_mode
        }.to(UserOption::DARK_MODE)

        expect(interface_color_mode).to have_dark_mode_forced, "the interface switches to dark mode"
        expect(mode_selector_in_sidebar).to have_dark_as_current_mode,
        "the selector in the sidebar should show dark mode as selected"

        page.refresh

        expect(interface_color_mode).to have_dark_mode_forced,
        "the interface should still be in dark mode after a page refresh"
        expect(mode_selector_in_sidebar).to have_dark_as_current_mode,
        "the selector in the sidebar should still show dark mode as selected"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_value(
          UserOption::DARK_MODE,
        ),
        "the dropdown should still have dark mode selected after a page refresh"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.interface_modes.dark"),
        ),
        "the dropdown should still have dark mode selected after a page refresh"
      end

      it "updates the selected color mode in preferences when the color mode is changed in the sidebar" do
        user_preferences_interface_page.visit(user)

        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_value(
          UserOption::AUTO_MODE,
        ),
        "the default value should be auto mode"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.interface_modes.auto"),
        ),
        "the default value should be auto mode"

        mode_selector_in_sidebar.expand
        mode_selector_in_sidebar.dark_option.click

        expect(interface_color_mode).to have_dark_mode_forced, "the interface switches to dark mode"
        expect(mode_selector_in_sidebar).to have_dark_as_current_mode,
        "the selector in the sidebar should show dark mode as selected"

        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_value(
          UserOption::DARK_MODE,
        ),
        "the dropdown should now have dark mode selected"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.interface_modes.dark"),
        ),
        "the dropdown should now have dark mode selected"

        page.refresh

        expect(interface_color_mode).to have_dark_mode_forced,
        "the interface should still be in dark mode after a page refresh"
        expect(mode_selector_in_sidebar).to have_dark_as_current_mode,
        "the selector in the sidebar should still show dark mode as selected after a page refresh"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_value(
          UserOption::DARK_MODE,
        ),
        "the dropdown should still have dark mode selected after a page refresh"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.interface_modes.dark"),
        ),
        "the dropdown should still have dark mode selected after a page refresh"
      end

      it "shows the mode selector when user has selected a dark color scheme" do
        user.user_option.update!(dark_scheme_id: color_scheme_dark_1.id)

        user_preferences_interface_page.visit(user)
        expect(page).to have_css(".interface-color-mode")
      end

      it "hides the mode selector when theme has identical light and dark schemes" do
        Theme.find_default.update!(
          color_scheme_id: color_scheme_light_1,
          dark_color_scheme_id: color_scheme_light_1,
        )

        user_preferences_interface_page.visit(user)
        expect(page).to have_no_css(".interface-color-mode")
      end

      it "hides the mode selector when theme has no dark scheme" do
        Theme.find_default.update!(color_scheme_id: color_scheme_light_1, dark_color_scheme_id: nil)

        user_preferences_interface_page.visit(user)
        expect(page).to have_no_css(".interface-color-mode")
      end
    end

    context "when changing another user's preferences as an admin" do
      fab!(:admin)

      before do
        sign_in(admin)
        admin.user_option.update!(interface_color_mode: UserOption::DARK_MODE)
        user.user_option.update!(interface_color_mode: UserOption::LIGHT_MODE)
        Theme.find_default.update!(
          color_scheme: ColorScheme.first,
          dark_color_scheme: ColorScheme.last,
        )
      end

      it "doesn't affect the viewing admin preferences and changes the target user's default preference for all devices" do
        user_preferences_interface_page.visit(user)

        expect(interface_color_mode).to have_dark_mode_forced,
        "the interface should be in dark mode for the admin"

        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_value(
          UserOption::LIGHT_MODE,
        ),
        "the dropdown should have light mode selected for the target user"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.interface_modes.light"),
        ),
        "the dropdown should have light mode selected for the target user"

        user_preferences_interface_page.color_mode_dropdown.expand
        user_preferences_interface_page.color_mode_dropdown.select_row_by_value(
          UserOption::AUTO_MODE,
        )
        expect(
          user_preferences_interface_page,
        ).to have_no_default_palette_and_mode_for_all_devices_checkbox,
        "the checkbox for applying the color mode to the current device is not present when editing another user's preferences"

        expect do user_preferences_interface_page.save_changes end.to change {
          user.user_option.reload.interface_color_mode
        }.to(UserOption::AUTO_MODE).and not_change { admin.user_option.reload.interface_color_mode }

        expect(interface_color_mode).to have_dark_mode_forced,
        "the interface should still be in dark mode for the admin"
        expect(mode_selector_in_sidebar).to have_dark_as_current_mode,
        "the selector in the sidebar should still show dark mode as selected for the admin"

        page.refresh

        expect(interface_color_mode).to have_dark_mode_forced,
        "the interface should still be in dark mode for the admin after a page refresh"
        expect(mode_selector_in_sidebar).to have_dark_as_current_mode,
        "the selector in the sidebar should still show dark mode as selected for the admin after a page refresh"

        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_value(
          UserOption::AUTO_MODE,
        ),
        "the dropdown should still have auto mode selected after a page refresh"
        expect(user_preferences_interface_page.color_mode_dropdown).to have_selected_name(
          I18n.t("js.user.color_schemes.interface_modes.auto"),
        ),
        "the dropdown should still have auto mode selected after a page refresh"
      end
    end
  end
end
