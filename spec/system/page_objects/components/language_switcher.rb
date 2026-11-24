# frozen_string_literal: true

module PageObjects
  module Components
    class LanguageSwitcher < PageObjects::Components::Base
      SELECTOR = "button[data-identifier='language-switcher']"

      def initialize
        @menu = PageObjects::Components::DMenu.new(SELECTOR)
      end

      def visible?
        page.has_css?(SELECTOR)
      end

      def not_visible?
        page.has_no_css?(SELECTOR)
      end

      def select_language(locale)
        @menu.expand
        @menu.option("[data-menu-option-id='#{locale}'] button").click
        page.assert_selector("html[lang='#{locale.tr("_", "-")}'] #main.ember-application")
      end
    end
  end
end
