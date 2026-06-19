# frozen_string_literal: true

module DiscourseWireframe
  # Per-user block-layout drafts (an editor concept). Drafts are private and
  # never live; publishing them to the live `block_layout` ThemeField is the
  # core `Admin::BlockLayoutsController#publish` path.
  class BlockLayoutDraftsController < ::Admin::AdminController
    requires_plugin DiscourseWireframe::PLUGIN_NAME

    def create
      DiscourseWireframe::SaveBlockLayoutDraft.call(service_params) do
        on_success { render json: { success: true } }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
        on_failure do
          render json: failed_json.merge(errors: ["Failed to save draft"]),
                 status: :unprocessable_entity
        end
      end
    end

    def destroy
      DiscourseWireframe::DiscardBlockLayoutDraft.call(service_params) do
        on_success { render json: { success: true } }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
        on_failure do
          render json: failed_json.merge(errors: ["Failed to discard draft"]),
                 status: :unprocessable_entity
        end
      end
    end

    private

    def service_params
      {
        params: params.permit(:theme_id, :outlet_name, :layout_json, :base_version_token),
        guardian: guardian,
      }
    end
  end
end
