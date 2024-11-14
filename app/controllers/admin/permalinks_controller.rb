# frozen_string_literal: true

class Admin::PermalinksController < Admin::AdminController
  before_action :fetch_permalink, only: %i[show update destroy]

  def index
    url = params[:filter]
    permalinks = Permalink.filter_by(url)
    render_serialized(permalinks, PermalinkSerializer)
  end

  def new
  end

  def edit
  end

  def show
    render_serialized(@permalink, PermalinkSerializer)
  end

  def create
    permalink =
      Permalink.create!(
        url: permalink_params[:url],
        permalink_type: permalink_params[:permalink_type],
        permalink_type_value: permalink_params[:permalink_type_value],
      )
    render_serialized(permalink, PermalinkSerializer)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages)
  end

  def update
    @permalink.update!(
      url: permalink_params[:url],
      permalink_type: permalink_params[:permalink_type],
      permalink_type_value: permalink_params[:permalink_type_value],
    )

    render_serialized(@permalink, PermalinkSerializer)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages)
  end

  def destroy
    @permalink.destroy
    render json: success_json
  end

  private

  def fetch_permalink
    @permalink = Permalink.find(params[:id])
  end

  def permalink_params
    params.require(:permalink).permit(:url, :permalink_type, :permalink_type_value)
  end
end
