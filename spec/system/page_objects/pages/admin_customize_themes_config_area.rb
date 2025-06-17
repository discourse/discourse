# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeThemesConfigArea < PageObjects::Pages::Base
      def visit(query_params = {})
        page.visit("/admin/config/customize?#{query_params.to_query}")
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

      def mark_as_active(theme)
        open_theme_menu(theme)
        find(".set-active").click
      end

      def has_badge?(theme, badge)
        find_theme_card(theme).has_css?(".theme-card__badge.#{badge}")
      end

      def has_no_badge?(theme, badge)
        find_theme_card(theme).has_no_css?(".theme-card__badge.#{badge}")
      end

      def has_themes?(names)
        expect(all(".theme-card__title").map(&:text)).to eq(names)
      end

      def toggle_selectable(theme)
        open_theme_menu(theme)
        find(".set-selectable").click
      end

      def click_edit(theme)
        find_theme_card(theme).find(".edit").click
      end
    end
  end
end
