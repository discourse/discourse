# frozen_string_literal: true

module CategoryHashtag
  extend ActiveSupport::Concern

  SEPARATOR = ":"

  class_methods do
    def query_from_hashtag_slug(category_slug)
      parent_slug, child_slug = category_slug.split(SEPARATOR, 2)

      categories = Category.where(slug: parent_slug)

      if child_slug
        Category.where(slug: child_slug, parent_category_id: categories.select(:id)).first
      else
        categories.where(parent_category_id: nil).first
      end
    end
  end

  def hashtag_slug
    full_slug.split("-").last(2).join(SEPARATOR)
  end
end
