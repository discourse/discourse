# frozen_string_literal: true

module PageObjects
  module Components
    class FilterNewNavigation < PageObjects::Components::Base
      def select_view(view)
        find("[data-filter-view='#{view}']").click
      end

      def select_subset(subset)
        find(".filter-new-navigation .topics-replies-toggle.--#{subset}").click
      end

      def has_counts?(topics:, replies:)
        has_css?(
          "[data-filter-view='new']",
          text: I18n.t("js.filters.new.title_with_count", count: topics + replies),
        ) &&
          has_css?(
            ".filter-new-navigation .--topics",
            text: I18n.t("js.filters.new.topics_with_count", count: topics),
          ) &&
          has_css?(
            ".filter-new-navigation .--replies",
            text: I18n.t("js.filters.new.replies_with_count", count: replies),
          )
      end

      def has_no_navigation?
        has_no_css?(".filter-new-navigation")
      end
    end
  end
end
