# frozen_string_literal: true

class Admin::PaletteController < Admin::AdminController
  # TODO: (martin) Maybe get all of these at once for initial cache?
  def settings
    render_json_dump(
      SiteSetting.all_settings(
        filter_names: params[:filter_names],
        filter_area: params[:filter_area],
        filter_plugin: params[:plugin],
        filter_categories: Array.wrap(params[:categories]),
        include_locale_setting: params[:filter_area] == "localization",
        basic_attributes: true,
      ),
    )
  end

  def themes_and_components
    themes = Theme.include_relations.order(:name)
    render_json_dump(serialize_data(themes, BasicThemeSerializer))
  end
end
