# frozen_string_literal: true

module DiscourseWireframe
  # The block-layout "designs" of a theme: local components the editor publishes
  # to instead of the theme itself. Creating one and the parent↔component mapping
  # is an editor concept, so it lives in the plugin rather than core's
  # `Admin::BlockLayoutsController`.
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

    # Every design across all themes, for the admin designs list.
    def index
      render json: { designs: DiscourseWireframe::BlockLayoutCompanion.all_designs }
    end

    # One design with its published layouts, for previewing it in the editor.
    def design
      detail = DiscourseWireframe::BlockLayoutCompanion.design_detail(params[:design_id].to_i)
      raise Discourse::NotFound if detail.nil?
      render json: detail
    end

    # The installed design's id (null when none) and every design of the given
    # parent theme. Used by the editor on entry to target the installed design and
    # to populate the design switcher.
    def show
      theme_id = params[:theme_id].to_i
      render json: {
               companion_id: DiscourseWireframe::BlockLayoutCompanion.companion_id_for(theme_id),
               designs: DiscourseWireframe::BlockLayoutCompanion.designs_for(theme_id),
             }
    end

    # Installs one of the parent's designs, unlinking the others.
    def update
      parent = Theme.find_by(id: params.require(:theme_id))
      raise Discourse::NotFound if parent.nil?

      if !DiscourseWireframe::BlockLayoutCompanion.install(parent, params.require(:design_id).to_i)
        raise Discourse::NotFound
      end

      render json: success_json
    end

    # Deletes one of the parent's designs.
    def destroy
      DiscourseWireframe::DeleteDesign.call(
        params: params.permit(:theme_id, :design_id),
        guardian: guardian,
      ) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
        on_model_not_found(:mapping) { raise Discourse::NotFound }
        on_model_not_found(:design) { raise Discourse::NotFound }
      end
    end

    private

    def service_params
      permitted = params.permit(:theme_id, :name, drafts: %i[outlet_name layout_json])

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
