class Admin::ColorSchemesController < Admin::AdminController

  before_action :fetch_color_scheme, only: [:update, :destroy]

  def index
    render_serialized(ColorScheme.base_color_schemes + ColorScheme.order('id ASC').all.to_a, ColorSchemeSerializer)
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
    @color_scheme = ColorScheme.find(params[:id])
  end

  def color_scheme_params
    params.permit(color_scheme: [:base_scheme_id, :name, colors: [:name, :hex]])[:color_scheme]
  end
end
