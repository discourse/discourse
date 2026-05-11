# frozen_string_literal: true

module PageObjects
  module Pages
    class DataExplorerIndex < PageObjects::Pages::Base
      def visit
        page.visit("/admin/plugins/discourse-data-explorer/queries")
        self
      end

      def has_query_row?(query)
        page.has_css?(".query-row", text: query.name)
      end

      def has_query_link?(query)
        page.has_css?(
          "a[href='/admin/plugins/discourse-data-explorer/queries/#{query.id}']",
          text: query.name,
        )
      end

      def has_no_query_link?(query)
        page.has_no_css?(
          "a[href='/admin/plugins/discourse-data-explorer/queries/#{query.id}']",
          text: query.name,
        )
      end

      def has_create_button?
        page.has_css?(".d-page-subheader .btn-primary")
      end

      def has_no_create_button?
        page.has_no_css?(".d-page-subheader .btn-primary")
      end

      def has_import_button?
        page.has_css?(".d-page-subheader .pick-files-button")
      end

      def has_no_import_button?
        page.has_no_css?(".d-page-subheader .pick-files-button")
      end

      def has_groups_column?
        page.has_css?(".heading.group-names")
      end

      def has_no_groups_column?
        page.has_no_css?(".heading.group-names")
      end

      def has_edit_row_button?
        page.has_css?(".d-table__cell-controls")
      end

      def has_no_edit_row_button?
        page.has_no_css?(".d-table__cell-controls")
      end
    end
  end
end
