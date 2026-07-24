# frozen_string_literal: true

module PageObjects
  module Modals
    class AdminOnboardingThemePicker < PageObjects::Modals::Base
      MODAL_SELECTOR = ".theme-picker-modal"
      CARD_SELECTOR = ".theme-picker-modal__card"
      NAME_SELECTOR = ".theme-card-preview__name"

      def open?
        has_css?(MODAL_SELECTOR)
      end

      def has_theme_cards?(**options)
        has_css?(CARD_SELECTOR, **options)
      end

      def first_selectable_theme_name
        find("#{CARD_SELECTOR}:not(.--selected) #{NAME_SELECTOR}", match: :first).text
      end

      def select_theme(name)
        find(CARD_SELECTOR, text: name).click
        find(".theme-picker-modal__footer .btn-primary").click
      end

      def select_first_selectable_theme
        first_selectable_theme_name.tap { |name| select_theme(name) }
      end
    end
  end
end
