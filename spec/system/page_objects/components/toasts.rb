# frozen_string_literal: true

module PageObjects
  module Components
    class Toasts < PageObjects::Components::Base
      def has_default?(message)
        has_css?(".fk-d-default-toast", text: message)
      end

      def has_success?(message)
        has_css?(".fk-d-default-toast.-success", text: message)
      end

      def close_button
        find(".fk-d-default-toast__close-container .btn")
      end

      def has_warning?(message)
        has_css?(".fk-d-default-toast.-warning", text: message)
      end

      def has_info?(message)
        has_css?(".fk-d-default-toast.-info", text: message)
      end

      def has_error?(message)
        has_css?(".fk-d-default-toast.-error", text: message)
      end
    end
  end
end
