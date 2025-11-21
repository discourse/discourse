# frozen_string_literal: true

module PageObjects
  module Pages
    class ReviewIndex < PageObjects::Pages::Base
      def expand_filters
        find(".expand-secondary-filters").click
      end

      def submit_filters
        find(".reviewable-filters-actions .refresh").click
      end

      def claimed_by_select
        PageObjects::Components::SelectKit.new(".claimed-by .select-kit")
      end
    end
  end
end
