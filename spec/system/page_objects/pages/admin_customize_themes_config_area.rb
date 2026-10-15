# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeThemesConfigArea < PageObjects::Pages::Base
      def visit(query_params = {})
        browser_page
          .goto("/admin/config/customize?#{query_params.to_query}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def find_theme_card(theme)
        browser_root.locator(".theme-card.#{theme.name.parameterize}").filter(visible: true)
      end

      def subheader
        browser_root.locator(".d-page-subheader").filter(visible: true)
      end

      def open_theme_menu(theme)
        find_theme_card(theme)
          .locator(".theme-card__footer-menu-trigger")
          .filter(visible: true)
          .click
      end

      def mark_as_default(theme)
        open_theme_menu(theme)
        browser_root.locator(".set-default").filter(visible: true).click
        expect(
          browser_page.locator("meta[name=discourse_theme_id][content='#{theme.id}']"),
        ).to PlaywrightMatchers.be_attached # wait for reload
      end

      def delete_theme(theme)
        open_theme_menu(theme)
        browser_root.locator(".delete").filter(visible: true).click
        confirmation_dialog = PageObjects::Components::Dialog.new
        confirmation_dialog.click_danger
        expect(confirmation_dialog).to be_closed
      end

      def has_default_badge?(theme)
        has_badge?(theme, "--default", text: I18n.t("admin_js.admin.customize.theme.default"))
      end

      def has_no_default_badge?(theme)
        has_no_badge?(theme, "--default")
      end

      def has_badge?(theme, badge, **kwargs)
        target = find_theme_card(theme).locator(".theme-card__badge.#{badge}").filter(visible: true)
        if kwargs[:text]
          PlaywrightMatchers.contain_text([kwargs[:text]], useInnerText: true).matches?(target)
        else
          PlaywrightMatchers.have_count(0).does_not_match?(target)
        end
      end

      def has_no_badge?(theme, badge)
        PlaywrightMatchers.have_count(0).matches?(
          find_theme_card(theme)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".theme-card__badge.#{badge}")
            .filter(visible: true),
        )
      end

      def has_disabled_delete_button?(theme)
        open_theme_menu(theme)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".--danger.delete[disabled]").filter(visible: true),
        )
      end

      def has_themes?(names)
        expect(
          browser_root
            .locator(".theme-card__title")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |element| element.inner_text.strip },
        ).to eq(names)
      end

      def has_theme_cards?(count:)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".themes-cards-container > .admin-config-area-card").filter(
            visible: true,
          ),
        )
      end

      def has_theme_named?(name)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".theme-card.#{name.parameterize}").filter(visible: true),
        )
      end

      def has_install_more_themes_card?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("admin_js.admin.customize.theme.install_more_themes"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".theme-card.--install-more").filter(visible: true))
      end

      def click_install_more_themes
        browser_root
          .locator(".theme-card.--install-more")
          .filter(visible: true)
          .locator(
            "[id=#{I18n.t("admin_js.admin.config_areas.themes_and_components.themes.install").to_s.to_json}], [name=#{I18n.t("admin_js.admin.config_areas.themes_and_components.themes.install").to_s.to_json}]",
          )
          .or(
            browser_root
              .locator(".theme-card.--install-more")
              .filter(visible: true)
              .get_by_role(
                "button",
                name: I18n.t("admin_js.admin.config_areas.themes_and_components.themes.install"),
              ),
          )
          .filter(visible: true)
          .click
        PageObjects::Modals::InstallTheme.new
      end

      def has_no_theme?(name)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".theme-card.#{name.parameterize}").filter(visible: true),
        )
      end

      def toggle_selectable(theme)
        open_theme_menu(theme)
        browser_root.locator(".set-selectable").filter(visible: true).click
      end

      def click_edit(theme)
        find_theme_card(theme).locator(".edit").filter(visible: true).click
      end

      def click_edit_by_name(name)
        browser_root
          .locator(".theme-card.#{name.parameterize}")
          .filter(visible: true)
          .locator(".edit")
          .filter(visible: true)
          .click
      end

      def click_install_button
        PageObjects::Components::AdminCustomizeThemeInstallButton.new.click
      end

      def screenshot_toggle_button(theme)
        find_theme_card(theme).locator(".theme-card-preview__screenshot-toggle").filter(
          visible: true,
        )
      end

      def has_screenshot_toggle_button?(theme)
        PlaywrightMatchers.have_count(0).does_not_match?(
          find_theme_card(theme).locator(".theme-card-preview__screenshot-toggle").filter(
            visible: true,
          ),
        )
      end

      def has_no_screenshot_toggle_button?(theme)
        PlaywrightMatchers.have_count(0).matches?(
          find_theme_card(theme)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".theme-card-preview__screenshot-toggle")
            .filter(visible: true),
        )
      end

      def click_screenshot_toggle(theme)
        find_theme_card(theme).hover
        screenshot_toggle_button(theme).click
      end

      def screenshot_image(theme)
        find_theme_card(theme).locator(".theme-card-preview__image").filter(visible: true)
      end

      def has_screenshot_with_icon?(theme, icon_name)
        find_theme_card(theme).hover
        PlaywrightMatchers.have_count(0).does_not_match?(
          find_theme_card(theme).locator(
            ".theme-card-preview__screenshot-toggle .d-icon-#{icon_name}",
          ).filter(visible: true),
        )
      end
    end
  end
end
