# frozen_string_literal: true

class DesignWizard::Action::ResolvePalette < Service::ActionBase
  option :palette_id

  def call
    return if palette_id.blank?
    return ColorScheme.find_by(id: palette_id) if palette_id.positive?

    find_materialized_built_in || materialize_built_in
  end

  private

  def find_materialized_built_in
    ColorScheme.find_by(base_scheme_id: palette_id, via_wizard: true)
  end

  def materialize_built_in
    ColorScheme.create_from_base(name: built_in_name, base_scheme_id: palette_id, via_wizard: true)
  end

  def built_in_name
    scheme_name = ColorScheme::NAMES_TO_ID_MAP.invert[palette_id]
    I18n.t("color_schemes.#{scheme_name.downcase.tr(" ", "_")}_theme_name")
  end
end
