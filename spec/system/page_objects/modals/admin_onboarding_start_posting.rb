# frozen_string_literal: true

module PageObjects
  module Modals
    class AdminOnboardingStartPosting < PageObjects::Modals::Base
      MODAL_SELECTOR = ".start-posting-options-modal"

      def open?
        has_css?("#{MODAL_SELECTOR}")
      end

      def closed?
        has_no_css?("#{MODAL_SELECTOR}")
      end

      def options
        all(".modal-options .option")
      end

      def option_count
        options.count
      end

      def select_option(option_class)
        find(".#{option_class} .btn").click
      end

      def has_predefined_option?
        has_css?(".predefined-option")
      end

      def cancel
        find(".cancel-button").click
      end
    end
  end
end
