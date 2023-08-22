# frozen_string_literal: true

module PageObjects
  module Modals
    class ChatChannelEdit < PageObjects::Modals::Base
      include SystemHelpers

      EDIT_MODAL_SELECTOR = PageObjects::Pages::ChatChannelAbout::EDIT_MODAL_SELECTOR
      SLUG_INPUT_SELECTOR = ".chat-channel-edit-name-slug-modal__slug-input"
      NAME_INPUT_SELECTOR = ".chat-channel-edit-name-slug-modal__name-input"

      def fill_in_slug(slug)
        within(EDIT_MODAL_SELECTOR) { find(SLUG_INPUT_SELECTOR).fill_in(with: slug) }

        self
      end

      def wait_for_auto_generated_slug
        wait_for_attribute(page.find(SLUG_INPUT_SELECTOR), :placeholder, "test-channel")
      end

      def fill_in_slug_input(slug)
        within(EDIT_MODAL_SELECTOR) { find(SLUG_INPUT_SELECTOR).fill_in(with: slug) }
      end

      def save_changes(successful: true)
        within(EDIT_MODAL_SELECTOR) { click_button(I18n.t("js.save")) }

        # ensures modal is closed after successfully saving
        page.has_no_css?(EDIT_MODAL_SELECTOR) if successful
      end

      def fill_and_save_slug(slug)
        fill_in_slug_input(slug)
        save_changes
        self
      end

      def fill_in_name_input(name)
        within(EDIT_MODAL_SELECTOR) { find(NAME_INPUT_SELECTOR).fill_in(with: name) }
      end

      def fill_and_save_name(name)
        fill_in_name_input(name)
        save_changes
        self
      end

      def has_slug_input?(value)
        within(EDIT_MODAL_SELECTOR) { find(SLUG_INPUT_SELECTOR).value == value }
      end

      def has_name_input?(value)
        within(EDIT_MODAL_SELECTOR) { find(NAME_INPUT_SELECTOR).value == value }
      end
    end
  end
end
