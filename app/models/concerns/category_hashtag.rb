# frozen_string_literal: true

module CategoryHashtag
  extend ActiveSupport::Concern

  SEPARATOR = ":".freeze

  class_methods do
    def query_from_hashtag_slug(category_slug)
      parent_slug, child_slug = category_slug.split(SEPARATOR, 2)

      category = Category.where(slug: parent_slug, parent_category_id: nil)

      if child_slug
        Category.where(slug: child_slug, parent_category_id: category.select(:id)).first
      else
        category.first
      end
    end
  end

  def hashtag_slug
    full_slug(SEPARATOR)
  end
end
