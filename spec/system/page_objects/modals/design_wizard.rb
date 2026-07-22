# frozen_string_literal: true

module PageObjects
  module Modals
    class DesignWizard < PageObjects::Modals::Base
      MODAL_SELECTOR = ".design-wizard-modal"

      def open?
        has_css?(MODAL_SELECTOR)
      end

      def closed?
        has_no_css?(MODAL_SELECTOR)
      end

      def has_theme_cards?(**options)
        has_css?("#{MODAL_SELECTOR}__theme-card", **options)
      end

      def select_theme(theme_id)
        find("#{MODAL_SELECTOR}__theme-card[data-theme-id='#{theme_id}']").click
      end

      def open_section(section_id)
        toggle = "#{MODAL_SELECTOR}__section[data-section-id='#{section_id}']"
        return if has_css?("#{toggle}.--open", wait: 0)
        find("#{toggle} #{MODAL_SELECTOR}__section-toggle").click
      end

      def select_palette(pair_key)
        find("#{MODAL_SELECTOR}__swatch[data-pair-key='#{pair_key}']").click
      end

      def toggle_user_selectable_palettes
        find("#{MODAL_SELECTOR}__user-selectable").click
      end

      def select_body_font(font_key)
        font_cards_in_group(0, font_key).click
      end

      def select_heading_font(font_key)
        font_cards_in_group(1, font_key).click
      end

      def select_homepage(key)
        index = key == "categories" ? 2 : 1
        find("#{MODAL_SELECTOR}__homepage-card:nth-child(#{index})").click
      end

      def has_preview_accent?(hex)
        find("#{MODAL_SELECTOR}__preview")[:style].include?("--dw-accent: ##{hex}")
      end

      def save
        find("#{MODAL_SELECTOR} .d-modal__footer .design-wizard-modal__save").click
      end

      def skip
        find("#{MODAL_SELECTOR} .d-modal__footer .design-wizard-modal__skip").click
      end

      private

      def font_cards_in_group(group_index, font_key)
        groups = all("#{MODAL_SELECTOR}__font-group")
        groups[group_index].find("#{MODAL_SELECTOR}__font-card.body-font-#{font_key.tr("_", "-")}")
      end
    end
  end
end
