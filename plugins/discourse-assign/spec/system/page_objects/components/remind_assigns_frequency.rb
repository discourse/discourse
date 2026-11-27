# frozen_string_literal: true

module PageObjects
  module Components
    class RemindAssignsFrequency < PageObjects::Components::Base
      SELECTOR = ".remind-assigns-frequency #remind-assigns-frequency"

      def has_frequency?
        page.has_css?(SELECTOR)
      end

      def has_no_frequency?
        page.has_css?(".user-preferences .save-changes") && page.has_no_css?(SELECTOR)
      end
    end
  end
end
