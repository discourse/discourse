# frozen_string_literal: true

class Admin::PermalinksController < Admin::AdminController
  before_action :fetch_permalink, only: [:destroy]

  def index
    url = params[:filter]
    permalinks = Permalink.filter_by(url)
    render_serialized(permalinks, PermalinkSerializer)
  end

  def create
    params.require(:url)
    params.require(:permalink_type)
    params.require(:permalink_type_value)

    if params[:permalink_type] == "tag_name"
      params[:permalink_type] = "tag_id"
      params[:permalink_type_value] = Tag.find_by_name(params[:permalink_type_value])&.id
    end

    permalink =
      Permalink.new(:url => params[:url], params[:permalink_type] => params[:permalink_type_value])
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
