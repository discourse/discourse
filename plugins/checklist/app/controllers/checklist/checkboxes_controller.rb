# frozen_string_literal: true

module Checklist
  class CheckboxesController < ::ApplicationController
    requires_plugin Checklist::PLUGIN_NAME
    requires_login

    def toggle
      Checklist::Toggle.call(params: toggle_params, guardian:) do
        on_success { head :no_content }
        on_failed_policy(:can_edit_post) { raise Discourse::InvalidAccess }
        on_model_not_found(:post) { raise Discourse::NotFound }
        on_failed_step(:validate_checkbox_at_offset) do |step|
          render json: failed_json.merge(error: step.error), status: :unprocessable_entity
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    private

    def toggle_params
      params.permit(:post_id, :checkbox_offset).to_h
    end
  end
end
