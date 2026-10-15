# frozen_string_literal: true

module PageObjects
  module Pages
    class ReviewIndex < PageObjects::Pages::Base
      def visit
        browser_page.goto("/review").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def filter_by_type(name)
        select_filter("review.filters.type.title", name)
      end

      def filter_by_reason(name)
        select_filter("review.filters.score_type.title", name)
      end

      def has_reason?(name)
        within_browser(filter_container("review.filters.score_type.title")) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(name)],
            useInnerText: true,
          ).matches?(browser_root.locator(".select-kit-header").filter(visible: true))
        end
      end

      def expand_filters
        browser_root.locator(".expand-secondary-filters").filter(visible: true).click
      end

      def submit_filters
        browser_root.locator(".reviewable-filters-actions .refresh").filter(visible: true).click
      end

      def claimed_by_select
        PageObjects::Components::SelectKit.new(".claimed-by .select-kit")
      end

      private

      def select_filter(label_key, name)
        within_browser(filter_container(label_key)) do
          PageObjects::Components::SelectKit.new(".select-kit").select_row_by_name(name)
        end
        self
      end

      def filter_container(label_key)
        browser_root
          .locator(".filter-label")
          .filter(visible: true)
          .filter(hasText: browser_exact_text_pattern(I18n.t("js.#{label_key}")))
          .locator("xpath=..")
      end
    end
  end
end
