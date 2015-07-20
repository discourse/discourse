class Admin::PermalinksController < Admin::AdminController

  before_filter :fetch_permalink, only: [:destroy]

  def index
    url = params[:filter]
    permalinks = Permalink.filter_by(url)
    render_serialized(permalinks, PermalinkSerializer)
  end

  def create
    params.require(:url)
    params.require(:permalink_type)
    params.require(:permalink_type_value)

    permalink = Permalink.new(:url => params[:url], params[:permalink_type] => params[:permalink_type_value])
    if permalink.save
      render_serialized(permalink, PermalinkSerializer)
    else
      render_json_error(permalink)
    end
  end

  def destroy
    @permalink.destroy
    render json: success_json
  end

  private

  def fetch_permalink
    @permalink = Permalink.find(params[:id])
  end

end
