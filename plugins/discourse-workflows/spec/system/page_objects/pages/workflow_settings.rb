# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class WorkflowSettings < PageObjects::Pages::Base
        def visit(workflow_id)
          page.visit("/admin/plugins/discourse-workflows/workflows/#{workflow_id}/settings")
          self
        end

        def has_field_value?(setting_field, value)
          within(row_for(setting_field)) { has_field?(with: value) }
        end

        def fill_in_field_value(setting_field, value)
          within(row_for(setting_field)) { fill_in(with: value) }
          self
        end

        def save_field_value(setting_field)
          within(row_for(setting_field)) { find(".setting-controls__ok").click }
          self
        end

        def click_manage_fields
          find(".workflows-settings__fields-manage").click
          self
        end

        def click_add_field_empty_state
          find(".admin-config-area-empty-list__cta-button").click
          self
        end

        def has_publish_notice?
          has_css?(".workflows-settings-publish-notice")
        end

        def has_no_publish_notice?
          has_no_css?(".workflows-settings-publish-notice")
        end

        def click_publish
          find(".workflows-settings-publish-notice__btn.btn-primary").click
          self
        end

        def click_discard
          find(".workflows-settings-publish-notice__btn.btn-default").click
          self
        end

        private

        def row_for(setting_field)
          "[data-setting='#{setting_field.key}']"
        end
      end
    end
  end
end
