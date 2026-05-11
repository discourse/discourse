# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminDashboard < PageObjects::Pages::Base
      def visit
        page.visit("/admin")
        self
      end

      def has_admin_notice?(message)
        has_css?(".dashboard-problem", text: message)
      end

      def has_no_admin_notice?(message)
        has_no_css?(".dashboard-problem", text: message)
      end

      def dismiss_notice(message)
        find(".dashboard-problem", text: message).find(".btn").click
      end

      def has_redesigned_toolbar?
        has_css?(".db-toolbar")
      end

      def has_active_period?(period)
        has_css?(".db-date-range input[value='#{period}']:checked")
      end

      def select_preset(period)
        find(".db-date-range label", text: preset_label(period)).click
        self
      end

      def has_custom_label_text?(text)
        has_css?(".db-date-range__custom", text: text)
      end

      def open_custom_date_range
        find(".db-date-range__custom").click
        self
      end

      private

      def preset_label(period)
        case period
        when "last_7_days"
          "Last 7 days"
        when "last_30_days"
          "Last 30 days"
        when "last_3_months"
          "Last 3 months"
        end
      end
    end
  end
end
