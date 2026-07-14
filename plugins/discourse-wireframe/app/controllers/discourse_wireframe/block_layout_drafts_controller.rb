# frozen_string_literal: true

module DiscourseWireframe
  # Per-user block-layout drafts (an editor concept). Drafts are private and
  # never live; publishing them to the live `block_layout` ThemeField is the
  # core `Admin::BlockLayoutsController#publish` path.
  class BlockLayoutDraftsController < ::Admin::AdminController
    requires_plugin DiscourseWireframe::PLUGIN_NAME

    # The current user's own drafts, optionally scoped to a set of theme ids
    # (the active stack). `data` is returned verbatim (the raw stored string the
    # client wrote); the client parses it and falls back to the live layout if
    # it can't. Never exposes another user's drafts.
    def index
      drafts = DiscourseWireframe::BlockLayoutDraft.where(user_id: current_user.id)
      theme_ids = Array.wrap(params[:theme_ids]).map(&:to_i).reject(&:zero?)
      drafts = drafts.where(theme_id: theme_ids) if theme_ids.present?

      render json: {
               drafts:
                 drafts.map do |draft|
                   {
                     theme_id: draft.theme_id,
                     outlet: draft.outlet,
                     data: draft.data,
                     base_version_token: draft.base_version_token,
                   }
                 end,
             }
    end

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
