# frozen_string_literal: true

module PageObjects
  module Components
    class SolvedStatusFilter < PageObjects::Components::Base
      SELECTOR = ".solved-status-filter"

      def visible?
        has_css?(SELECTOR)
      end

      def filter_solved
        select_kit.expand
        select_kit.select_row_by_value("solved")
        self
      end

      def filter_unsolved
        select_kit.expand
        select_kit.select_row_by_value("unsolved")
        self
      end

      private

      def select_kit
        @select_kit ||= PageObjects::Components::SelectKit.new(SELECTOR)
      end
    end
  end
end
