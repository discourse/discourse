# frozen_string_literal: true

class Admin::ColorSchemesController < Admin::AdminController
  before_action :fetch_color_scheme, only: %i[update destroy]

  def index
    schemes =
      ColorScheme.without_theme_owned_palettes.with_experimental_system_theme_palettes.order(
        "color_schemes.id ASC",
      )

    schemes = schemes.where(theme_id: nil) if params[:exclude_theme_owned]

    render_serialized(ColorScheme.base_color_schemes + schemes.to_a, ColorSchemeSerializer)
  end

  def create
    color_scheme = ColorScheme.create(color_scheme_params)
    if color_scheme.valid?
      render json: color_scheme, root: false
    else
      render_json_error(color_scheme)
    end
  end

  def update
    color_scheme = ColorSchemeRevisor.revise(@color_scheme, color_scheme_params)
    if color_scheme.valid?
      render json: color_scheme, root: false
    else
      render_json_error(color_scheme)
    end
  end

  def destroy
    @color_scheme.destroy
    render json: success_json
  end

  private

  def fetch_color_scheme
    @color_scheme = ColorScheme.without_theme_owned_palettes.find(params[:id])
  end

  def color_scheme_params
    params.permit(
      color_scheme: [:base_scheme_id, :name, :user_selectable, colors: %i[name hex dark_hex]],
    )[
      :color_scheme
    ]
  end
end
