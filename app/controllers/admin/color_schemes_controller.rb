class Admin::ColorSchemesController < Admin::AdminController

  before_filter :fetch_color_scheme, only: [:update, :destroy]

  def index
    render_serialized([ColorScheme.base] + ColorScheme.current_version.order('id ASC').all.to_a, ColorSchemeSerializer)
  end

  def create
    color_scheme = ColorScheme.create(color_scheme_params)
    if color_scheme.valid?
      recompile!
      render json: color_scheme, root: false
    else
      render_json_error(color_scheme)
    end
  end

  def update
    color_scheme = ColorSchemeRevisor.revise(@color_scheme, color_scheme_params)
    if color_scheme.valid?
      recompile!
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

  def recompile!
    # Touch sentry file to trigger recompilation
    File.open(DiscourseSassCompiler::COLOR_VERSION_SENTRY_FILE, "w") { }

    DiscourseStylesheets.new(:desktop).compile
    DiscourseStylesheets.new(:mobile).compile
  end

  def fetch_color_scheme
    @color_scheme = ColorScheme.find(params[:id])
  end

  def color_scheme_params
    params.permit(color_scheme: [:enabled, :name, colors: [:name, :hex]])[:color_scheme]
  end
end
