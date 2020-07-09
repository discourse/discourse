# frozen_string_literal: true

class CategoryHashtagsController < ApplicationController
  requires_login

  def check
    category_slugs = params[:category_slugs]

    ids = category_slugs.map { |category_slug| Category.query_from_hashtag_slug(category_slug).try(:id) }

    slugs_and_urls = {}

    Category.secured(guardian).where(id: ids).order(:id).each do |category|
      slugs_and_urls[category.slug] ||= category.url
      slugs_and_urls[category.slug_path.last(2).join(':')] ||= category.url
    end

    render json: {
      valid: slugs_and_urls.map { |slug, url| { slug: slug, url: url } }
    }
  end
end
