# frozen_string_literal: true
class Admin::Config::ColorPalettesController < Admin::AdminController
  def index
  end

  def show
    render_serialized(
      ColorScheme.without_theme_owned_palettes.find(params[:id]),
      ColorSchemeSerializer,
      root: false,
    )
  end
end
