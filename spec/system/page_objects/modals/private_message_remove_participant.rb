# frozen_string_literal: true

module PageObjects
  module Modals
    class PrivateMessageRemoveParticipant < PageObjects::Components::Base
      def open?
        has_css?("#dialog-holder .dialog-content")
      end

      def closed?
        has_no_css?("#dialog-holder .dialog-content")
      end

      def body
        find("#dialog-holder .dialog-content .dialog-body")
      end

      def confirm_removal
        find("#dialog-holder .dialog-content .dialog-footer .btn-danger").click
      end

      def cancel
        find("#dialog-holder .dialog-content .dialog-footer .btn-default").click
      end
    end
  end
end
