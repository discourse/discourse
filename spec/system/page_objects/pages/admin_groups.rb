# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminGroups < AdminBase
      def visit
        page.visit("/admin/groups")
        self
      end

      def search(filter)
        find(".groups-header-filters input").fill_in(with: filter)
        self
      end

      def has_groups?(groups)
        page.has_css?(".group-info-name", count: groups.length, wait: 5) &&
          all(".group-info-name", wait: 5).map(&:text) == groups
      end

      def has_no_groups?
        page.has_no_css?(".group-info-name")
      end
    end
  end
end
