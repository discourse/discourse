# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class SettingFields < PageObjects::Pages::Base
        BASE_PATH = "/admin/plugins/discourse-workflows/workflows"

        def visit_index(workflow_id)
          page.visit("#{BASE_PATH}/#{workflow_id}/settings/fields")
          self
        end

        def visit_new(workflow_id)
          page.visit("#{BASE_PATH}/#{workflow_id}/settings/fields/new")
          self
        end

        def visit_edit(workflow_id, setting_field)
          page.visit("#{BASE_PATH}/#{workflow_id}/settings/fields/#{setting_field.id}/edit")
          self
        end

        def has_setting_field?(setting_field)
          has_css?(".d-table__overview-name", text: setting_field.label) &&
            has_css?(".workflows-setting-field-key", text: setting_field.key)
        end

        def has_no_setting_field?(setting_field)
          has_no_css?(".d-table__overview-name", text: setting_field.label)
        end

        def click_add_field
          find(".workflows-settings__fields-add").click
          self
        end

        def click_add_field_empty_state
          find(".admin-config-area-empty-list__cta-button").click
          self
        end

        def click_edit(setting_field)
          within(row_for(setting_field)) { find(".workflows-setting-fields-table__edit").click }
          self
        end

        def click_delete(setting_field)
          within(row_for(setting_field)) { find(".workflows-setting-fields-table__delete").click }
          self
        end

        def has_label_value?(value)
          has_field?("label", with: value)
        end

        def has_key_value?(value)
          has_field?("key", with: value)
        end

        def fill_in_label(label)
          fill_in("label", with: label)
          self
        end

        def fill_in_key(key)
          fill_in("key", with: key)
          self
        end

        def submit
          find(".form-kit__button").click
          self
        end

        private

        def row_for(setting_field)
          find(".workflows-setting-fields-table__row", text: setting_field.label)
        end
      end
    end
  end
end
