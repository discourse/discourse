# frozen_string_literal: true

class CategoryHashtagsController < ApplicationController
  requires_login

  def check
    category_slugs = params[:category_slugs]

    ids = category_slugs.map { |category_slug| Category.query_from_hashtag_slug(category_slug).try(:id) }

    valid_categories = Category.secured(guardian).where(id: ids).map do |category|
      { slug: category.hashtag_slug, url: category.url_with_id }
    end.compact

    render json: { valid: valid_categories }
  end
end
