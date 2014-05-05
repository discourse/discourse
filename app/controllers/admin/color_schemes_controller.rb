class Admin::ColorSchemesController < Admin::AdminController

  before_filter :fetch_color_scheme, only: [:update, :destroy]

  def index
    render_serialized(ColorScheme.current_version.order('id ASC').all.to_a, ColorSchemeSerializer)
  end

  def create
    color_scheme = ColorScheme.create(color_scheme_params)
    render json: color_scheme, root: false
  end

  def update
    render json: ColorSchemeRevisor.revise(@color_scheme, color_scheme_params), root: false
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
    params.permit(color_scheme: [:enabled, :name, colors: [:name, :hex, :opacity]])[:color_scheme]
  end
end
