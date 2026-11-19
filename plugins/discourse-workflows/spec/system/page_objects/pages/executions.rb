# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class Executions < PageObjects::Pages::Base
        def visit_index
          page.visit("/admin/plugins/discourse-workflows/executions")
          self
        end

        def visit_detail(workflow_id, execution_id)
          page.visit(
            "/admin/plugins/discourse-workflows/workflows/#{workflow_id}/executions/#{execution_id}",
          )
          self
        end

        def open_execution(execution_id)
          page.find(".workflows-executions-manager__id", text: "##{execution_id}").click
          self
        end

        def click_row(execution_id)
          page.find(".d-table__row[data-item-id='#{execution_id}']").click
          self
        end

        def select_row(execution_id)
          page.find(
            ".d-table__row[data-item-id='#{execution_id}'] .workflows-admin-table__checkbox",
          ).click
          self
        end

        def enable_bulk_select
          page.find(
            ".workflows-admin-table__toolbar .btn",
            text: I18n.t("js.discourse_workflows.executions.select"),
          ).click
          self
        end

        def has_delete_selected_button?
          page.has_css?(
            ".btn-danger",
            text: I18n.t("js.discourse_workflows.executions.delete_selected"),
          )
        end

        def open_workflow(name)
          page.find(".d-table__overview-link", text: name).click
          self
        end

        def has_execution_with_status?(status)
          page.has_css?(".workflows-executions-manager__status.--#{status}")
        end

        def has_no_executions?
          page.has_css?(".workflows-empty-state")
        end

        def has_detail?
          page.has_css?(".workflows-execution-detail")
        end

        def has_step?(name)
          page.has_css?(".workflows-execution-detail__step-name", text: name)
        end
      end
    end
  end
end
