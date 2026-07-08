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
    end
  end
end
