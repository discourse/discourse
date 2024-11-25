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
    permalink = Permalink.create!(permalink_params)
    render_serialized(permalink, PermalinkSerializer)
  rescue ActiveRecord::RecordInvalid => e
    render_json_error(e.record.errors.full_messages)
  end

  def update
    @permalink.update!(permalink_params)
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
    permitted_params =
      params.require(:permalink).permit(:url, :permalink_type, :permalink_type_value)

    {
      url: permitted_params[:url],
      topic_id: extract_param(permitted_params, "topic"),
      post_id: extract_param(permitted_params, "post"),
      category_id: extract_param(permitted_params, "category"),
      tag_id:
        extract_param(permitted_params, "tag").then do |tag_name|
          (Tag.where(name: tag_name).pluck(:id).first || -1) if tag_name
        end,
      user_id: extract_param(permitted_params, "user"),
      external_url: extract_param(permitted_params, "external_url"),
    }
  end

  def extract_param(permitted_params, type)
    permitted_params[:permalink_type] == type ? permitted_params[:permalink_type_value] : nil
  end
end
