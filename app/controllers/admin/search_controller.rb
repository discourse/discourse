# frozen_string_literal: true

class Admin::SearchController < Admin::AdminController
  RESULT_TYPES = %w[page setting theme component report].freeze

  def index
    respond_to do |format|
      format.json do
        render_json_dump(
          settings:
            SiteSetting.all_settings(
              filter_names: params[:filter_names],
              filter_area: params[:filter_area],
              filter_plugin: params[:plugin],
              filter_categories: Array.wrap(params[:categories]),
              include_locale_setting: params[:filter_area] == "localization",
              basic_attributes: true,
            ),
          themes_and_components:
            serialize_data(Theme.include_relations.order(:name), BasicThemeSerializer),
          reports: Reports::ListQuery.call,
        )
      end

      format.html { render body: nil }
    end
  end
end
