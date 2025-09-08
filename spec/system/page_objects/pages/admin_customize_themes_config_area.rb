# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeThemesConfigArea < PageObjects::Pages::Base
      def visit(query_params = {})
        page.visit("/admin/config/customize?#{query_params.to_query}")
        self
      end

      def find_theme_card(theme)
        find(".theme-card.#{theme.name.parameterize}")
      end

      def subheader
        find(".d-page-subheader")
      end

      def open_theme_menu(theme)
        find_theme_card(theme).find(".theme-card__footer-menu-trigger").click
      end

      def mark_as_default(theme)
        open_theme_menu(theme)
        find(".set-default").click
      end

      def delete_theme(theme)
        open_theme_menu(theme)
        find(".delete").click
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
        find_theme_card(theme).has_css?(".theme-card__badge.#{badge}", **kwargs)
      end

      def has_no_badge?(theme, badge)
        find_theme_card(theme).has_no_css?(".theme-card__badge.#{badge}")
      end

      def has_disabled_delete_button?(theme)
        open_theme_menu(theme)
        has_css?(".btn-danger.delete[disabled]")
      end

      def has_themes?(names)
        expect(all(".theme-card__title").map(&:text)).to eq(names)
      end

      def has_no_theme?(name)
        has_no_css?(".theme-card.#{name.parameterize}")
      end

      def toggle_selectable(theme)
        open_theme_menu(theme)
        find(".set-selectable").click
      end

      def click_edit(theme)
        find_theme_card(theme).find(".edit").click
      end

      def click_install_button
        PageObjects::Components::AdminCustomizeThemeInstallButton.new.click
      end
    end
  end
end
