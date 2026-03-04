# frozen_string_literal: true

module PageObjects
  module Pages
    class DataExplorerQueryRunner < PageObjects::Pages::Base
      def visit_group_report(group_name, query_id)
        page.visit("/g/#{group_name}/reports/#{query_id}")
        self
      end

      def visit_admin_query(query_id, query_string: nil)
        path = "/admin/plugins/discourse-data-explorer/queries/#{query_id}"
        path += "?#{query_string}" if query_string.present?
        page.visit(path)
        self
      end

      def has_param_field?(name, value)
        page.has_field?(name, with: value)
      end

      def run_query
        page.find(".query-run .query-run__submit").click
        self
      end

      def click_edit_name
        page.find(".edit-query-name").click
        self
      end

      def fill_query_name(text)
        page.find(".name-text-field input").fill_in(with: text)
        self
      end

      def click_save_and_run
        page.find(".query-run .query-run__save-and-run").click
        self
      end

      def has_query_name?(text)
        page.has_css?(".query-name-display", text: text)
      end

      def has_no_params?
        page.has_no_css?(".query-params")
      end

      def has_result_header?
        page.has_css?(".query-results .result-header")
      end

      def has_result_row_count?(count)
        page.has_css?(".query-results .query-result-row", count: count)
      end

      def has_result_cell?(text)
        page.has_css?(".query-results .query-result-cell", text: text)
      end

      def has_result_cell_at?(row_index, col_index, text:)
        page.has_css?(
          ".query-results .query-result-row:nth-of-type(#{row_index}) .query-result-cell:nth-of-type(#{col_index})",
          text: text,
        )
      end
    end
  end
end
