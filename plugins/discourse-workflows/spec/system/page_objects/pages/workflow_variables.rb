# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class WorkflowVariables < PageObjects::Pages::Base
        BASE_PATH = "/admin/plugins/discourse-workflows/workflows"

        def visit_index(workflow_id)
          page.visit("#{BASE_PATH}/#{workflow_id}/variables")
          self
        end

        def visit_manage(workflow_id)
          page.visit("#{BASE_PATH}/#{workflow_id}/variables/manage")
          self
        end

        def visit_new(workflow_id)
          page.visit("#{BASE_PATH}/#{workflow_id}/variables/new")
          self
        end

        def visit_edit(workflow_id, variable)
          page.visit("#{BASE_PATH}/#{workflow_id}/variables/#{variable.id}/edit")
          self
        end

        def has_variable?(variable)
          has_css?(".d-table__overview-name", text: variable.label) &&
            has_css?(".workflows-variable-key", text: variable.key)
        end

        def has_no_variable?(variable)
          has_no_css?(".d-table__overview-name", text: variable.label)
        end

        def has_variable_value?(variable, value)
          within(value_row_for(variable)) { has_field?(with: value) }
        end

        def fill_in_variable_value(variable, value)
          within(value_row_for(variable)) { fill_in(with: value) }
          self
        end

        def save_variable_value(variable)
          within(value_row_for(variable)) { find(".setting-controls__ok").click }
          self
        end

        def click_add_variable
          find(".workflows-variables__add").click
          self
        end

        def click_add_variable_empty_state
          find(".admin-config-area-empty-list__cta-button").click
          self
        end

        def click_edit(variable)
          within(row_for(variable)) { find(".workflows-variables-table__edit").click }
          self
        end

        def click_delete(variable)
          within(row_for(variable)) { find(".workflows-variables-table__delete").click }
          self
        end

        def has_key_value?(value)
          has_field?("key", with: value)
        end

        def fill_in_key(key)
          fill_in("key", with: key)
          self
        end

        def submit
          find(".form-kit__button").click
          self
        end

        def has_publish_notice?
          has_css?(".workflows-variables-publish-notice")
        end

        def has_no_publish_notice?
          has_no_css?(".workflows-variables-publish-notice")
        end

        def click_publish
          find(".workflows-variables-publish-notice__btn.btn-primary").click
          self
        end

        def click_discard
          find(".workflows-variables-publish-notice__btn.btn-default").click
          self
        end

        private

        def row_for(variable)
          find(".workflows-variables-table__row", text: variable.label)
        end

        def value_row_for(variable)
          "[data-setting='#{variable.key}']"
        end
      end
    end
  end
end
