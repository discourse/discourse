# frozen_string_literal: true

module PageObjects
  module Pages
    class DataExplorerQueries < PageObjects::Pages::Base
      ROW = ".query-row"
      SEARCH_INPUT = ".d-filter-controls__input"
      TAG_FILTER = ".query-tag-filter .d-multi-select-trigger__selected-item"

      def visit
        page.visit("/admin/plugins/discourse-data-explorer/queries")
        self
      end

      def has_query_count?(count)
        page.has_css?(ROW, count:)
      end

      def has_queries?(queries)
        has_query_count?(queries.size) && queries.all? { page.has_css?(row(it)) }
      end

      def has_author?(query, user)
        page.has_css?("#{row(query)} .query-created-by", text: user.username)
      end

      def has_groups?(query, groups)
        groups.all? { page.has_css?("#{row(query)} .query-group-names a", exact_text: it.name) }
      end

      def has_last_run?(query)
        page.has_css?("#{row(query)} .query-created-at .relative-date")
      end

      def has_no_last_run?(query)
        page.has_css?(row(query)) &&
          page.has_no_css?("#{row(query)} .query-created-at .relative-date")
      end

      def has_view_only?(query)
        has_action?(query, I18n.t("js.explorer.view_query"))
      end

      def has_editable?(query)
        has_action?(query, I18n.t("js.edit"))
      end

      def has_tag_filters?(tag_names)
        page.has_css?(TAG_FILTER, count: tag_names.size) &&
          tag_names.all? { page.has_css?(TAG_FILTER, exact_text: it) }
      end

      def has_search?(text)
        page.has_css?(SEARCH_INPUT) { it.value == text }
      end

      def filter_by_tag(query, tag_name)
        page.find("#{row(query)} .query-tags .d-table-badge", exact_text: tag_name).click
        self
      end

      def search(text)
        page.find(SEARCH_INPUT).fill_in(with: text)
        self
      end

      def scroll_to_end
        page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
        self
      end

      def open(query)
        page.find("#{row(query)} .d-table__overview-link").click
        self
      end

      def back_to_list
        page.find(".back-button").click
        self
      end

      def delete(query)
        open_menu(query)
        page.find(".query-row__delete").click
        PageObjects::Components::Dialog.new.click_danger
        self
      end

      def toggle_dashboard(query)
        open_menu(query)
        page.find(".query-row__dashboard-toggle").click
        self
      end

      def has_dashboard_action?(query, label)
        open_menu(query)
        found = page.has_css?(".query-row__dashboard-toggle", exact_text: label)
        page.send_keys(:escape)
        found
      end

      def has_no_query?(query)
        page.has_no_css?(row(query))
      end

      def has_no_delete_option?(query)
        open_menu(query)
        absent =
          page.has_css?(".query-row__dashboard-toggle") && page.has_no_css?(".query-row__delete")
        page.send_keys(:escape)
        absent
      end

      private

      def open_menu(query)
        page.find("#{row(query)} .query-row__menu-trigger[aria-expanded='false']").click
      end

      def row(query)
        "#{ROW}:has(a[href$='/queries/#{query.id}'])"
      end

      def has_action?(query, label)
        page.has_css?("#{row(query)} .d-table__cell-actions a", exact_text: label)
      end
    end
  end
end
