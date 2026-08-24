# frozen_string_literal: true

module PageObjects
  module Pages
    class AiLogs < PageObjects::Pages::Base
      def visit(query = nil)
        path = "/admin/plugins/discourse-ai/ai-logs"
        page.visit(query ? "#{path}?#{query}" : path)
        self
      end

      def select_period(label)
        find(".ai-logs__periods .btn", text: label).click
        self
      end

      def select_outcome(label)
        select_filter(:outcome, label)
      end

      def select_model(label)
        select_filter(:model, label)
      end

      def select_feature(label)
        feature_filter.expand
        feature_filter.search(label)
        feature_filter.select_row_by_value(label)
        self
      end

      def feature_filter_value
        feature_filter.value
      end

      def clear_filters
        find(".d-filter-controls__reset").click
        self
      end

      def search(value)
        find("input[placeholder='#{I18n.t("js.discourse_ai.logs.search_placeholder")}']").fill_in(
          with: value,
        )
        self
      end

      def filter_value(key)
        find(".d-filter-controls__dropdown--#{key}").value
      end

      def has_tinted_filter_toggle?
        page.evaluate_script(<<~JS)
          (() => {
            const icon = document.querySelector(
              ".ai-logs .d-filter-controls__toggle-filters .d-icon"
            );
            const probe = (color) => {
              const el = document.createElement("span");
              el.style.color = `var(${color})`;
              document.body.appendChild(el);
              const result = getComputedStyle(el).color;
              el.remove();
              return result;
            };
            return [probe("--tertiary"), probe("--tertiary-hover")].includes(
              getComputedStyle(icon).color
            );
          })()
        JS
      end

      def has_no_tinted_filter_toggle?
        !has_tinted_filter_toggle?
      end

      def has_expanded_filter_dropdowns?
        page.has_css?(".d-filter-controls__dropdown", count: 2)
      end

      def open_log(log)
        find(%(.ai-logs__row[data-log-id="#{log.id}"])).find(".btn").click
        self
      end

      def open_retention
        find(
          ".ai-logs .btn-primary",
          text: I18n.t("js.discourse_ai.logs.retention.configure"),
        ).click
        self
      end

      def has_log?(log)
        page.has_css?(%(.ai-logs__row[data-log-id="#{log.id}"]))
      end

      def has_no_log?(log)
        page.has_no_css?(%(.ai-logs__row[data-log-id="#{log.id}"]))
      end

      def has_payload?(text)
        page.has_css?(".ai-payload-viewer__content", text:)
      end

      def has_retention_modal?
        page.has_css?(".ai-log-retention-modal")
      end

      private

      def feature_filter
        PageObjects::Components::SelectKit.new(".ai-logs__feature-filter .combo-box")
      end

      def select_filter(key, label)
        find(".d-filter-controls__dropdown--#{key}").select(label)
        self
      end
    end
  end
end
