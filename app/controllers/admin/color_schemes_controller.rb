# frozen_string_literal: true

class Admin::ColorSchemesController < Admin::AdminController
  before_action :fetch_color_scheme, only: %i[update destroy]

  def index
    schemes = ColorScheme.includes(:base_scheme).order("color_schemes.id ASC")

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
    update_params = color_scheme_params

    if @color_scheme.theme_id.present?
      if (update_params.key?(:name) && update_params[:name] != @color_scheme.name) ||
           update_params[:colors].present? ||
           (
             update_params.key?(:base_scheme_id) &&
               update_params[:base_scheme_id] != @color_scheme.base_scheme_id
           )
        raise Discourse::InvalidAccess
      end
    end

    color_scheme = ColorSchemeRevisor.revise(@color_scheme, update_params)
    update_theme_default_scheme!
    if color_scheme.valid?
      render json: color_scheme, root: false
    else
      render_json_error(color_scheme)
    end
  end

  def destroy
    raise Discourse::InvalidAccess if @color_scheme.theme_id.present?

    @color_scheme.destroy
    render json: success_json
  end

  private

  def fetch_color_scheme
    @color_scheme = ColorScheme.find(params[:id])
  end

  def color_scheme_params
    params.permit(
      color_scheme: [
        :base_scheme_id,
        :name,
        :user_selectable,
        :default_light_on_theme,
        :default_dark_on_theme,
        colors: %i[name hex],
      ],
    )[
      :color_scheme
    ]
  end

  def update_theme_default_scheme!
    update_opts = {}
    if color_scheme_params.has_key?(:default_light_on_theme)
      update_opts[:color_scheme_id] = if color_scheme_params[:default_light_on_theme].to_s !=
           "false"
        @color_scheme.id
      else
        nil
      end
    end
    if color_scheme_params.has_key?(:default_dark_on_theme)
      update_opts[:dark_color_scheme_id] = if color_scheme_params[:default_dark_on_theme].to_s !=
           "false"
        @color_scheme.id
      else
        nil
      end
    end
    Theme.find_default.update!(update_opts)
  end
end
