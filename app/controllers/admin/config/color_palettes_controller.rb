# frozen_string_literal: true
class Admin::Config::ColorPalettesController < Admin::AdminController
  def show
    render_serialized(ColorScheme.find(params[:id]), ColorSchemeSerializer, root: false)
  end
end
