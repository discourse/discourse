# frozen_string_literal: true

module PageObjects
  module Pages
    class AiUsage < PageObjects::Pages::Base
      def visit
        page.visit "/admin/plugins/discourse-ai/ai-usage"
      end

      def has_usage_content?
        page.has_css?(".ai-usage")
      end

      def click_custom_date_button
        find(".ai-usage__period-buttons .btn-default:last-child").click
      end

      def has_custom_date_picker?
        page.has_css?(".ai-usage__custom-date-pickers")
      end

      def set_start_date(date_string)
        # Find the first date input (from date)
        date_inputs = all(".ai-usage__custom-date-pickers input[type='date']")
        date_inputs[0].set(date_string)
      end

      def set_end_date(date_string)
        # Find the second date input (to date)
        date_inputs = all(".ai-usage__custom-date-pickers input[type='date']")
        date_inputs[1].set(date_string)
      end

      def get_start_date_value
        all(".ai-usage__custom-date-pickers input[type='date']")[0].value
      end

      def get_end_date_value
        all(".ai-usage__custom-date-pickers input[type='date']")[1].value
      end

      def click_refresh
        find(".ai-usage__custom-date-pickers .btn", text: I18n.t("js.refresh")).click
      end

      def has_loading_spinner?
        page.has_css?(".conditional-loading-spinner .spinner")
      end

      def wait_for_data_load
        # Wait for loading spinner to disappear
        expect(page).not_to have_css(".conditional-loading-spinner .spinner", wait: 10)
      end

      def has_summary_data?
        page.has_css?(".ai-usage__summary .d-stat-tiles")
      end
    end
  end
end
