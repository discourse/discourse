# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatChannelSettings < PageObjects::Pages::Base
      EDIT_MODAL_SELECTOR = ".chat-modal-edit-channel-name"

      def open_edit_modal
        click_button(class: "edit-name-slug-btn")
        find(EDIT_MODAL_SELECTOR) # wait for modal to appear
        PageObjects::Modals::ChatChannelEdit.new
      end

      def has_slug?(slug)
        page.has_css?(".c-channel-settings__slug", text: slug)
      end

      def has_name?(name)
        page.has_css?(".c-channel-settings__name", text: name)
      end

      def has_open_button?(disabled: false)
        if disabled
          page.has_css?(".open-btn[disabled]")
        else
          page.has_css?(".open-btn:not([disabled])")
        end
      end

      def has_no_open_button?
        page.has_no_css?(".open-btn")
      end

      def has_close_button?
        page.has_css?(".close-btn")
      end

      def has_no_close_button?
        page.has_no_css?(".close-btn")
      end

      def hover_open_button
        find(".open-btn").hover
        self
      end
    end
  end
end
