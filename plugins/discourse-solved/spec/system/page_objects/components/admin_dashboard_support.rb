# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardSupport < PageObjects::Components::Base
      SELECTOR = ".db-main [data-section-id='support']"

      def has_section?
        has_css?(SELECTOR)
      end

      def has_no_section?
        has_no_css?(SELECTOR)
      end

      def has_headline?(text)
        has_css?("#{SELECTOR} .db-section__subintro h3", text: text)
      end

      def has_kpi?(label)
        has_css?("#{SELECTOR} .db-section__metric-label", text: label)
      end

      def has_topic_outcome?(label, count:)
        within("#{SELECTOR} .db-support-outcomes__row", text: label) do
          has_css?(".db-support-outcomes__share", exact_text: count.to_s)
        end
      end

      def has_answerer?(label)
        has_css?("#{SELECTOR} .db-support-answerers .db-whos-posting__bar-label", text: label)
      end

      def has_response_time_bucket?(label)
        has_css?("#{SELECTOR} .db-support-response__label", text: label)
      end

      def has_category_filter?
        has_css?("#{SELECTOR} .db-support__filter")
      end

      def has_no_category_filter?
        has_no_css?("#{SELECTOR} .db-support__filter")
      end

      CATEGORY_FILTER = "#{SELECTOR} .db-support__filter .category-selector"

      def category_filter
        PageObjects::Components::SelectKit.new(CATEGORY_FILTER)
      end

      def expand_category_filter
        category_filter.expand
        self
      end

      def select_category(category)
        expand_category_filter
        category_filter.select_row_by_value(category.id)
        self
      end

      def close_category_filter
        category_filter.collapse
        self
      end

      def has_selected_category?(category)
        has_css?("#{CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']")
      end

      def has_no_selected_category?(category)
        has_no_css?("#{CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']")
      end
    end
  end
end
