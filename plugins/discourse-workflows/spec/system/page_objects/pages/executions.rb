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
