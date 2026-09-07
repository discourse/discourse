# frozen_string_literal: true

module PageObjects
  module Pages
    class DataExplorerQueryRunner < PageObjects::Pages::Base
      def visit_group_report(group_name, query_id)
        page.visit("/g/#{group_name}/reports/#{query_id}")
        self
      end

      def visit_admin_query(query_id, query_string: nil, params: nil)
        path = "/admin/plugins/discourse-data-explorer/queries/#{query_id}"
        query_string = "params=#{CGI.escape(params.to_json)}" if params.present?
        path += "?#{query_string}" if query_string.present?
        page.visit(path)
        self
      end

      def has_param_field?(name, value)
        page.has_field?(name, with: value)
      end

      def run_query
        page.find(".query-run-split__primary").click
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
        # Run auto-saves when dirty. Wait for the label to morph to "Save
        # changes and run" so we know the debounced dirty flag has fired.
        page.find(".query-run-split__primary", text: /Save changes and run/i)
        run_query
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

      def show_table
        # Chart is the default view when chartable; some assertions need rows.
        # The input is a hidden radio inside a label, so click the label.
        page.execute_script(<<~JS)
          const input = document.querySelector(
            ".query-results-modes input[value='table']"
          );
          if (input && !input.checked) {
            input.closest("label").click();
          }
        JS
        self
      end

      def has_result_row_count?(count)
        show_table
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

      def visit_new_query
        page.visit("/admin/plugins/discourse-data-explorer/queries/new")
        self
      end

      def fill_new_query_name(text)
        page.find(".query-new [data-name='name'] input").fill_in(with: text)
        self
      end

      def fill_new_query_description(text)
        page.find(".query-new [data-name='description'] textarea").fill_in(with: text)
        self
      end

      def fill_new_query_sql(text)
        page.execute_script(
          "document.querySelector('.query-new .editor-panel .ace_editor').env.editor.setValue(arguments[0], 1);",
          text,
        )
        self
      end

      def select_new_query_groups(*group_names)
        select_kit = PageObjects::Components::SelectKit.new(".query-new .query-group-select")
        select_kit.expand
        group_names.each { |name| select_kit.select_row_by_name(name) }
        self
      end

      def has_query_groups?(*group_names)
        PageObjects::Components::SelectKit.new(
          ".query-edit .groups .select-kit",
        ).has_selected_names?(*group_names)
      end

      def submit_new_query
        page.find(".query-new .btn-primary").click
        self
      end

      def has_query_description?(text)
        page.has_css?(".query-edit .desc", text: text)
      end

      def has_no_result_header?
        page.has_no_css?(".query-results .result-header")
      end

      def has_cached_result_notice?
        page.has_css?(".cached-result-notice")
      end

      def has_no_cached_result_notice?
        page.has_no_css?(".cached-result-notice")
      end

      def has_chart?
        page.has_css?(".query-results .chart-canvas-container")
      end

      def collapse_schema
        page.find(".schema__toggle.--collapse").click
        self
      end

      # Clicked through the DOM. Stacked, this affordance sits past the left edge
      # of the viewport, where a real click cannot land on it.
      def expand_schema
        page.execute_script("document.querySelector('.schema__toggle.--expand').click()")
        self
      end

      # Drags the editor separator, negative to shrink.
      def resize_panes_by(y)
        drag_with_pointer(from: ".query-editor .grippie", by: { y: y })
        self
      end

      # The floor the separator announces for the layout as it stands.
      def pane_floor
        page.find(".query-editor .grippie")["aria-valuemin"].to_f
      end

      # How much taller the panes' content is than the box clipping it. One pixel
      # is not overflow; the two readings round independently.
      def pane_overflow
        page.evaluate_script(<<~JS)
          (() => {
            const panes = document.querySelector(".query-editor .panels-flex");
            return Math.max(0, panes.scrollHeight - panes.clientHeight - 1);
          })()
        JS
      end
    end
  end
end
