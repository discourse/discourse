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
    end
  end
end
