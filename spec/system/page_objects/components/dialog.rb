# frozen_string_literal: true

module PageObjects
  module Components
    class Dialog < PageObjects::Components::Base
      def closed?
        has_no_css?(".dialog-container")
      end

      def open?
        has_css?(".dialog-container")
      end

      def has_content?(content)
        find(".dialog-container").has_content?(content)
      end

      def click_yes
        find(".dialog-footer .btn-primary").click
      end

      def click_danger
        find(".dialog-footer .btn-danger").click
      end

      alias click_ok click_yes

      def click_no
        find(".dialog-footer .btn-default").click
      end

      def has_confirm_button_disabled?
        has_css?(".dialog-footer .btn-danger[disabled]")
      end

      def has_no_confirm_button_disabled?
        has_no_css?(".dialog-footer .btn-danger[disabled]")
      end

      def fill_in_confirmation_phrase(phrase)
        find(".dialog-body input.confirmation-phrase").fill_in(with: phrase)
      end
    end
  end
end
