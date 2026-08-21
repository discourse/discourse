# frozen_string_literal: true

module Checklist
  class CheckboxesController < ::ApplicationController
    requires_plugin Checklist::PLUGIN_NAME
    requires_login

    def toggle
      Checklist::ToggleCheckbox.call(service_params) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:post) { raise Discourse::NotFound }
        on_failed_policy(:can_edit_post) { raise Discourse::InvalidAccess }
        on_failed_policy(:checkboxes_unchanged) do
          render json: failed_json.merge(errors: [I18n.t("checklist.checkboxes_changed")]),
                 status: :conflict
        end
        on_failed_step(:revise_post) do |step|
          render json: failed_json.merge(errors: [step.error]), status: :unprocessable_entity
        end
        on_lock_not_acquired(:post_id) { render json: failed_json, status: :too_many_requests }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end
  end
end
