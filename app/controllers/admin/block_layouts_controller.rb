# frozen_string_literal: true

# Saves a single `block_layout` ThemeField via the visual editor's "Save"
# button. Wraps `Themes::SaveBlockLayout`, which handles auto-redirection to
# a child theme component when the target theme is Git-imported.
class Admin::BlockLayoutsController < Admin::AdminController
  def create
    Themes::SaveBlockLayout.call(service_params) do
      on_success do |target_theme:, redirected:, child_created:|
        render json: {
                 success: true,
                 # The id of the theme that ultimately holds the field — the
                 # parent theme when no redirection happened, otherwise the
                 # newly-created (or pre-existing) child component. The client
                 # uses this to update its session-draft → theme-layer
                 # collapse with the right `themeId`.
                 target_theme_id: target_theme.id,
                 target_theme_name: target_theme.name,
                 redirected: redirected,
                 child_created: child_created,
               }
      end
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_model_not_found(:theme) { raise Discourse::NotFound }
      on_failed_step(:guard_against_bake_error) do |step|
        render json: failed_json.merge(errors: [step.error]), status: :unprocessable_entity
      end
      on_failure do
        render json: failed_json.merge(errors: ["Failed to save layout"]),
               status: :unprocessable_entity
      end
    end
  end

  private

  def service_params
    {
      params: params.permit(:theme_id, :outlet_name, :layout_json, :force_parent),
      guardian: guardian,
    }
  end
end
