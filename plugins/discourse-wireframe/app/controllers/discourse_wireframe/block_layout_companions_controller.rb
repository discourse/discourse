# frozen_string_literal: true

module DiscourseWireframe
  # The block-layout "companion" component for a theme that can't be published to
  # directly (a core system theme or a Git theme). Creating it and the
  # parent↔component mapping is an editor concept, so it lives in the plugin rather
  # than core's `Admin::BlockLayoutsController`.
  class BlockLayoutCompanionsController < ::Admin::AdminController
    requires_plugin DiscourseWireframe::PLUGIN_NAME

    # Create (or reuse) the parent theme's companion component, overlay the carried
    # drafts, and record the mapping. Returns the companion's theme id.
    def create
      DiscourseWireframe::EnsureBlockLayoutCompanion.call(service_params) do
        on_success { |theme_id:| render json: { theme_id: } }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
        on_model_not_found(:theme) { raise Discourse::NotFound }
        on_failed_step(:validate_drafts) do |step|
          render json: failed_json.merge(errors: [step.error]), status: :unprocessable_entity
        end
        on_failure do
          render json: failed_json.merge(errors: ["Failed to create customization component"]),
                 status: :unprocessable_entity
        end
      end
    end

    # The id of the given parent theme's companion (a live child carrying the
    # mapping), or null when there is none. Used by the editor on entry to target an
    # existing companion instead of re-offering to set one up.
    def show
      companion_id =
        DiscourseWireframe::BlockLayoutCompanion.companion_id_for(params[:theme_id].to_i)
      render json: { companion_id: }
    end

    private

    def service_params
      permitted = params.permit(:theme_id, drafts: %i[outlet_name layout_json])

      # The browser encodes an array of objects as `drafts[0][outlet_name]=...`,
      # which Rack parses into a positional `{ "0" => {...} }` hash rather than an
      # array; normalize it back to an array so the service reads each draft.
      if permitted[:drafts].is_a?(ActionController::Parameters)
        permitted[:drafts] = permitted[:drafts].values
      end

      { params: permitted, guardian: guardian }
    end
  end
end
