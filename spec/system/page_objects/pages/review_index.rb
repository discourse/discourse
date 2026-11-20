# frozen_string_literal: true

module PageObjects
  module Pages
    class ReviewIndex < PageObjects::Pages::Base
      def visit
        page.visit("/review")
        self
      end

      def filter_by_type(name)
        select_filter("review.filters.type.title", name)
      end

      def filter_by_reason(name)
        select_filter("review.filters.score_type.title", name)
      end

      def has_reason?(name)
        within(filter_container("review.filters.score_type.title")) do
          page.has_css?(".select-kit-header", text: name)
        end
      end

      def expand_filters
        find(".expand-secondary-filters").click
      end

      def submit_filters
        find(".reviewable-filters-actions .refresh").click
      end

      def claimed_by_select
        PageObjects::Components::SelectKit.new(".claimed-by .select-kit")
      end

      private

      def select_filter(label_key, name)
        within(filter_container(label_key)) do
          PageObjects::Components::SelectKit.new(".select-kit").select_row_by_name(name)
        end
        self
      end

      def filter_container(label_key)
        find(".filter-label", exact_text: I18n.t("js.#{label_key}")).find(:xpath, "..")
      end
    end
  end
end
