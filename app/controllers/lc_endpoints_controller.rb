class LcEndpointsController < ActionController::Base
  def get_topics_for_categories
    @categories = Category.where(slug: params[:category_names])
    render json: @categories.to_json(include: :topics)
  end
end
