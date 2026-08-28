# frozen_string_literal: true

module Checklist
  class CheckboxesController < ::ApplicationController
    MAX_TOGGLES_PER_MINUTE = 120

    requires_plugin Checklist::PLUGIN_NAME
    requires_login
    before_action :rate_limit_checklist_toggles, only: :toggle

    def toggle
      Checklist::ToggleCheckbox.call(service_params) do
        on_success do |post:, resolved_toggles:|
          revised =
            resolved_toggles.any? { |toggle| toggle.checkbox.checked? != toggle.request[:checked] }
          render json: { updated_at: post.updated_at, revised: }
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:post) { raise Discourse::NotFound }
        on_failed_policy(:can_edit_post) { raise Discourse::InvalidAccess }
        on_failed_policy(:post_unchanged) do |post:, params:|
          render_checklist_conflict(post, retryable: checklist_conflict_retryable?(post, params))
        end
        on_failed_policy(:checkbox_counts_unchanged) { |post:| render_checklist_conflict(post) }
        on_failed_policy(:checkboxes_found) { |post:| render_checklist_conflict(post) }
        on_failed_policy(:checkboxes_toggleable) do
          render json: failed_json.merge(errors: [I18n.t("checklist.checkbox_locked")]),
                 status: :unprocessable_entity
        end
        on_failed_step(:revise_post) do |step, post:, params:|
          if step.error == :edit_conflict
            render_checklist_conflict(post, retryable: checklist_conflict_retryable?(post, params))
          else
            render json: failed_json.merge(errors: [I18n.t("checklist.revision_failed")]),
                   status: :unprocessable_entity
          end
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    private

    def rate_limit_checklist_toggles
      limiter = RateLimiter.new(current_user, "checklist_toggle", MAX_TOGGLES_PER_MINUTE, 1.minute)
      toggle_count = [Array.wrap(params[:toggles]).size, 1].max
      [toggle_count, Checklist::ToggleCheckbox::MAX_BATCH_SIZE + 1].min.times { limiter.performed! }
    end

    def checklist_conflict_retryable?(post, params)
      Checklist::ToggleCheckbox.retryable_conflict?(
        post:,
        expected_updated_at: params.expected_updated_at,
      )
    end

    def render_checklist_conflict(post, retryable: false)
      render json:
               failed_json.merge(
                 errors: [I18n.t("checklist.checkboxes_changed")],
                 updated_at: post.reload.updated_at.iso8601(3),
                 retryable:,
               ),
             status: :conflict
    end
  end
end
