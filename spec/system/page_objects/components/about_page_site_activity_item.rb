# frozen_string_literal: true

module PageObjects
  module Components
    class AboutPageSiteActivityItem < PageObjects::Components::Base
      attr_reader :container

      def initialize(container, translation_key:)
        @container = container
        @translation_key = translation_key
      end

      def has_count?(count, formatted_number)
        container.find(".about__activities-item-count").has_text?(
          I18n.t("js.#{@translation_key}", count: count, formatted_number:),
        )
      end

      def has_text?(text)
        container.find(".about__activities-item-count").has_text?(text)
      end

      def has_1_day_period?
        period_element.has_text?(I18n.t("js.about.activities.periods.today"))
      end

      def has_7_days_period?
        period_element.has_text?(I18n.t("js.about.activities.periods.last_7_days"))
      end

      def has_all_time_period?
        period_element.has_text?(I18n.t("js.about.activities.periods.all_time"))
      end

      # used by plugins
      def has_custom_count?(text)
        container.find(".about__activities-item-count").has_text?(text)
      end

      # used by plugins
      def has_custom_period?(text)
        period_element.has_text?(text)
      end

      private

      def period_element
        container.find(".about__activities-item-period")
      end
    end
  end
end
