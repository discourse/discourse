class CategoryHashtagsController < ApplicationController
  before_filter :ensure_logged_in

  def check
    category_slugs = params[:category_slugs]
    category_slugs.each(&:downcase!)

    valid_categories = Category.secured(guardian).where(slug: category_slugs).map do |category|
      { slug: category.slug, url: category.url_with_id }
    end.compact

    render json: { valid: valid_categories }
  end
end
