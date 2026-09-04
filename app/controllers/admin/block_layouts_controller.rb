# frozen_string_literal: true

# Publishing and resetting of the live `block_layout` ThemeField on behalf of
# edit-driven tooling.
#
# - POST   block-layouts           → publish (live write + broadcast), 409 on a stale token
# - DELETE block-layouts           → reset to default (delete the live field)
# - POST   block-layouts/export    → produce the repo-file JSON for one outlet (download)
# - POST   block-layouts/duplicate → fork a Git theme into an editable copy
#
# Per-user drafts and the block-layout "companion" component are plugin concerns
# (see the discourse-wireframe plugin's endpoints); core only manages live fields
# and theme-level operations.
class Admin::BlockLayoutsController < Admin::AdminController
  def publish
    Themes::SaveBlockLayout.call(service_params) do
      on_success do |theme:, field:|
        render json: {
                 success: true,
                 theme_id: theme.id,
                 version_token: Themes::BlockLayoutVersion.token_for(field.value_baked),
               }
      end
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_failed_policy(:theme_is_not_git) do
        render json:
                 failed_json.merge(errors: ["Publishing is disabled for themes managed by Git."]),
               status: :unprocessable_entity
      end
      on_model_not_found(:theme) { raise Discourse::NotFound }
      on_failed_step(:guard_stale_publish) do |current_version:, published_at:|
        render json:
                 failed_json.merge(
                   errors: ["This layout was changed by someone else; reload and try again."],
                   current_version:,
                   published_at:,
                 ),
               status: :conflict
      end
      on_failed_step(:guard_against_bake_error) do |step|
        render json: failed_json.merge(errors: [step.error]), status: :unprocessable_entity
      end
      on_failure do
        render json: failed_json.merge(errors: ["Failed to save layout"]),
               status: :unprocessable_entity
      end
    end
  end

  def destroy
    Themes::ResetBlockLayout.call(service_params) do
      on_success { |theme:| render json: { success: true, theme_id: theme.id } }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_failed_policy(:theme_is_not_git) do
        render json: failed_json.merge(errors: ["Reset is disabled for themes managed by Git."]),
               status: :unprocessable_entity
      end
      on_model_not_found(:theme) { raise Discourse::NotFound }
      on_failure do
        render json: failed_json.merge(errors: ["Failed to reset layout"]),
               status: :unprocessable_entity
      end
    end
  end

  def export
    Themes::ExportBlockLayout.call(service_params) do
      on_success { |filename:, content:| render json: { filename:, content: } }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_model_not_found(:theme) { raise Discourse::NotFound }
      on_model_not_found(:source_value) { raise Discourse::NotFound }
      on_failed_step(:build_payload) do |step|
        render json: failed_json.merge(errors: [step.error]), status: :unprocessable_entity
      end
      on_failure do
        render json: failed_json.merge(errors: ["Failed to export layout"]),
               status: :unprocessable_entity
      end
    end
  end

  def duplicate
    Themes::DuplicateForEditing.call(service_params) do
      on_success { |theme_id:| render json: { theme_id: } }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_failed_policy(:theme_is_duplicable) do
        render json: failed_json.merge(errors: ["This theme cannot be duplicated."]),
               status: :unprocessable_entity
      end
      on_model_not_found(:theme) { raise Discourse::NotFound }
      on_failed_step(:validate_drafts) do |step|
        render json: failed_json.merge(errors: [step.error]), status: :unprocessable_entity
      end
      on_failed_step(:duplicate_theme) do |step|
        render json:
                 failed_json.merge(
                   errors: [step.exception&.message || "Failed to duplicate theme"],
                 ),
               status: :unprocessable_entity
      end
      on_failure do
        render json: failed_json.merge(errors: ["Failed to duplicate theme"]),
               status: :unprocessable_entity
      end
    end
  end

  private

  def service_params
    permitted =
      params.permit(
        :theme_id,
        :outlet_name,
        :layout_json,
        :expected_version_token,
        drafts: %i[outlet_name layout_json],
      )

    # The browser encodes an array of objects as `drafts[0][outlet_name]=...`,
    # which Rack parses into a positional `{ "0" => {...} }` hash rather than an
    # array. The service's array attribute would wrap that whole hash as a single
    # element and lose each draft's keys, so normalize it back to an array here.
    if permitted[:drafts].is_a?(ActionController::Parameters)
      permitted[:drafts] = permitted[:drafts].values
    end

    { params: permitted, guardian: guardian }
  end
end
