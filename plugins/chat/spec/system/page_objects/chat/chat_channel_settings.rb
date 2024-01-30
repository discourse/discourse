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
    end
  end
end
