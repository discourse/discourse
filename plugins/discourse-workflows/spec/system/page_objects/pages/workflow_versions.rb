# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class WorkflowVersions < PageObjects::Pages::Base
        def visit(workflow_id)
          page.visit("/admin/plugins/discourse-workflows/workflows/#{workflow_id}/versions")
          self
        end

        def has_versions?(count)
          page.has_css?(".workflows-versions-manager tbody .d-table__row", count: count)
        end

        def has_author?(username)
          page.has_css?(".workflows-versions__author", text: username)
        end

        def has_version?(version)
          row_for(version)
          true
        end

        def revert(version)
          within(row_for(version)) { find(".workflows-versions__revert").click }
          self
        end

        private

        def row_for(version)
          find(
            ".workflows-versions-manager tbody .d-table__row[data-item-id='#{version.version_id}']",
          )
        end
      end
    end
  end
end
