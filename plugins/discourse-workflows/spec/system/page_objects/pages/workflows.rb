# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
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
            ".workflows-index__row[data-item-id='#{workflow.id}'] .workflows-index__warning",
          )
        end

        def has_no_failed_workflow?(workflow)
          page.has_no_css?(
            ".workflows-index__row[data-item-id='#{workflow.id}'] .workflows-index__warning",
          )
        end

        def has_no_workflows?
          page.has_css?(".workflows-empty-state")
        end

        def has_no_workflow?(name)
          page.has_no_css?(".workflows-index__name", text: name)
        end

        def has_workflow_tag?(workflow, tag)
          page.has_css?(
            ".workflows-index__row[data-item-id='#{workflow.id}'] .workflows-index__tags .d-table-badge",
            text: tag,
          )
        end

        def click_workflow_tag(workflow, tag)
          find(
            ".workflows-index__row[data-item-id='#{workflow.id}'] .workflows-index__tags .d-table-badge",
            text: tag,
          ).click
          self
        end

        def filter_by_tag(tag)
          find(".workflows-index__tag-filter").click
          find(".d-multi-select__search-input").fill_in(with: tag)
          find(".d-multi-select__result", text: tag).click
          page.send_keys(:escape)
          self
        end

        def reset_filters
          find(".d-filter-controls__reset").click
          self
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
end
