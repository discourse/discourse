# frozen_string_literal: true

module PageObjects
  module Modals
    class DTemplatesInsertTemplate < PageObjects::Modals::Base
      include SystemHelpers

      MODAL_SELECTOR = ".d-templates-modal"

      def open_with_keyboard_shortcut
        send_keys([PLATFORM_KEY_MODIFIER, :shift, "i"])
      end

      def open?
        super && finished_loading?
      end

      def finished_loading?
        has_no_css?("#{MODAL_SELECTOR} .spinner")
      end

      def select_template(id)
        find("#template-item-#{id} .templates-apply").click
      end
    end
  end
end
