# frozen_string_literal: true

class Admin::Config::DesignWizardController < Admin::AdminController
  def index
    core_themes =
      Theme
        .where(id: Theme::CORE_THEMES.values)
        .includes(:locale_fields, theme_fields: :upload)
        .order(:id)
    default_theme = Theme.find_default

    render json: {
             themes:
               core_themes.map do |theme|
                 {
                   id: theme.id,
                   name: theme.name,
                   description: theme.description,
                   default: theme.id == default_theme&.id,
                   color_scheme_id: theme.color_scheme_id,
                   dark_color_scheme_id: theme.dark_color_scheme_id,
                   screenshot_light_url: theme.screenshot_light_url,
                   screenshot_dark_url: theme.screenshot_dark_url,
                   palette_pairs: DesignWizard::PalettePairs.for_theme(theme),
                 }
               end,
             current_theme: current_theme_payload(default_theme),
             base_font: SiteSetting.base_font,
             heading_font: SiteSetting.heading_font,
             homepage: SiteSetting.homepage,
             palettes_user_selectable: palettes_user_selectable?(default_theme),
           }
  end

  def update
    DesignWizard::Apply.call(service_params) do |result|
      on_success { render json: success_json }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_model_not_found(:theme) { raise Discourse::NotFound }
      on_failed_policy(:current_user_is_admin) { raise Discourse::InvalidAccess }
      on_failed_policy(:palettes_available_to_theme) do
        render json:
                 failed_json.merge(errors: [I18n.t("design_wizard.errors.palette_unavailable")]),
               status: :unprocessable_entity
      end
      on_failure { render json: failed_json, status: :unprocessable_entity }
    end
  end

  private

  def current_theme_payload(default_theme)
    return if default_theme.nil? || Theme::CORE_THEMES.value?(default_theme.id)

    { id: default_theme.id, name: default_theme.name }
  end

  def palettes_user_selectable?(default_theme)
    offered = ColorScheme.where(theme_id: default_theme&.id)
    offered = ColorScheme.where(via_wizard: true) if offered.none?
    offered.exists? && offered.where(user_selectable: false).none?
  end
end
