# frozen_string_literal: true

module PageObjects
  module Pages
    class Workflows < PageObjects::Pages::Base
      def visit_index
        page.visit("/admin/plugins/discourse-workflows")
        self
      end

      def has_workflow?(name)
        page.has_css?(".workflows-index__name", text: name)
      end

      def has_failed_workflow?(workflow)
        page.has_css?(
          ".workflows-index__row[data-workflow-id='#{workflow.id}'] .workflows-index__warning",
        )
      end

      def has_no_failed_workflow?(workflow)
        page.has_no_css?(
          ".workflows-index__row[data-workflow-id='#{workflow.id}'] .workflows-index__warning",
        )
      end

      def has_no_workflows?
        page.has_css?(".workflows-empty-state")
      end

      def click_new_workflow
        find(".workflows-index__new-btn").click
        self
      end

      def click_workflow(name)
        find(".workflows-index__name", text: name).find("a").click
        self
      end
    end
  end
end
