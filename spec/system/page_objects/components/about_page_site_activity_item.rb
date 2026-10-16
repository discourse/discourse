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
        contain_text(
          browser_text_pattern(I18n.t("js.#{@translation_key}", count: count, formatted_number:)),
          useInnerText: true,
        ).matches?(container.locator(".about__activities-item-count").filter(visible: true))
      end

      def has_displayed_text?(text)
        contain_text(browser_text_pattern(text), useInnerText: true).matches?(
          container.locator(".about__activities-item-count").filter(visible: true),
        )
      end

      def has_1_day_period?
        contain_text(
          browser_text_pattern(I18n.t("js.about.activities.periods.today")),
          useInnerText: true,
        ).matches?(period_element)
      end

      def has_7_days_period?
        contain_text(
          browser_text_pattern(I18n.t("js.about.activities.periods.last_7_days")),
          useInnerText: true,
        ).matches?(period_element)
      end

      def has_all_time_period?
        contain_text(
          browser_text_pattern(I18n.t("js.about.activities.periods.all_time")),
          useInnerText: true,
        ).matches?(period_element)
      end

      # used by plugins
      def has_custom_count?(text)
        contain_text(browser_text_pattern(text), useInnerText: true).matches?(
          container.locator(".about__activities-item-count").filter(visible: true),
        )
      end

      # used by plugins
      def has_custom_period?(text)
        contain_text(browser_text_pattern(text), useInnerText: true).matches?(period_element)
      end

      private

      def period_element
        container.locator(".about__activities-item-period").filter(visible: true)
      end
    end
  end
end
