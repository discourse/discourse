# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class DataTables < PageObjects::Pages::Base
        def visit_index
          page.visit("/admin/plugins/discourse-workflows/data-tables")
          self
        end

        def visit_show(id)
          page.visit("/admin/plugins/discourse-workflows/data-tables/#{id}")
          self
        end

        def has_data_table?(name)
          page.has_css?(".d-table__overview-name", text: name)
        end

        def has_no_data_table?(name)
          page.has_no_css?(".d-table__overview-name", text: name)
        end

        def click_add_data_table
          if page.has_css?(".workflows-empty-state", wait: 5)
            find(".workflows-empty-state .btn-primary").click
          else
            find(".workflows-admin-table__toolbar .btn-primary").click
          end
          self
        end

        def fill_data_table_name(name)
          find(".data-table-modal input[name='name']").fill_in(with: name)
          self
        end

        def submit_data_table_modal
          find(".data-table-modal .btn-primary[type='submit']").click
          self
        end

        def has_viewer?
          page.has_css?(".workflows-data-table-viewer")
        end

        def has_add_row_button?
          page.has_css?(".workflows-data-table-viewer__add-row")
        end

        def has_row?(count: nil)
          if count
            page.has_css?(".workflows-data-table-viewer__row", count: count)
          else
            page.has_css?(".workflows-data-table-viewer__row")
          end
        end

        def click_add_row
          find(".workflows-data-table-viewer__add-row .btn-transparent").click
          self
        end
      end
    end
  end
end
