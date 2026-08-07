# frozen_string_literal: true

module PageObjects
  module Pages
    class AiUsage < PageObjects::Pages::Base
      def visit(query: nil)
        path = "/admin/plugins/discourse-ai/ai-usage"
        path = "#{path}?#{query}" if query

        page.visit path
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

      def has_features_total_row?
        page.has_css?(".ai-usage__features-table .ai-usage__total-row")
      end

      def has_models_total_row?
        page.has_css?(".ai-usage__models-table .ai-usage__total-row")
      end

      def has_users_total_row?
        page.has_css?(".ai-usage__users-table .ai-usage__total-row")
      end

      def model_selector
        PageObjects::Components::SelectKit.new(".ai-usage__model-selector")
      end

      def feature_selector
        PageObjects::Components::SelectKit.new(".ai-usage__feature-selector")
      end

      def has_selected_period?(period)
        page.has_css?(".ai-usage__period-buttons .btn-primary", text: period_label(period))
      end

      def has_query_param?(name, value)
        page.has_current_path?(query_param_pattern(name, value), url: true)
      end

      def has_no_query_param?(name, value)
        page.has_no_current_path?(query_param_pattern(name, value), url: true)
      end

      def reload
        page.refresh
      end

      def select_period(period)
        find(".ai-usage__period-buttons .btn", text: period_label(period)).click

        self
      end

      private

      def query_param_pattern(name, value)
        /[?&]#{Regexp.escape(name)}=#{Regexp.escape(ERB::Util.url_encode(value.to_s))}(?:&|$)/
      end

      def period_label(period)
        case period
        when :day
          I18n.t("js.discourse_ai.usage.periods.last_day")
        when :week
          I18n.t("js.discourse_ai.usage.periods.last_week")
        when :month
          I18n.t("js.discourse_ai.usage.periods.last_month")
        end
      end
    end
  end
end
