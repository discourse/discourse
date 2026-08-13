# frozen_string_literal: true

class Admin::Config::DesignWizardController < Admin::AdminController
  def index
    core_themes =
      Theme
        .where(id: Theme::CORE_THEMES.values)
        .includes(:locale_fields, theme_fields: :upload)
        .order(:id)

    render_serialized(Theme.find_default, DesignWizardSerializer, root: false, themes: core_themes)
  end

  def update
    DesignWizard::Apply.call(service_params) do |result|
      on_success { render json: success_json }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_model_not_found(:theme) { raise Discourse::NotFound }
      # unreachable via AdminController, but don't let it 422 if that changes
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_failed_policy(:palettes_available_to_theme) do
        render json:
                 failed_json.merge(errors: [I18n.t("design_wizard.errors.palette_unavailable")]),
               status: :unprocessable_entity
      end
      on_failed_step(:update_site_settings) do
        render json:
                 failed_json.merge(
                   errors: [I18n.t("design_wizard.errors.site_settings_update_failed")],
                 ),
               status: :unprocessable_entity
      end
      on_failure { render json: failed_json, status: :unprocessable_entity }
    end
  end
end
