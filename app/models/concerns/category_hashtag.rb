# frozen_string_literal: true

module CategoryHashtag
  extend ActiveSupport::Concern

  SEPARATOR = ":"

  class_methods do
    def query_from_hashtag_slug(category_slug)
      slug_path = category_slug.split(SEPARATOR)
      return nil if slug_path.empty? || slug_path.size > 2

      if SiteSetting.slug_generation_method == "encoded"
        slug_path.map! { |slug| CGI.escape(slug) }
      end

      parent_slug, child_slug = slug_path.last(2)
      categories = Category.where(slug: parent_slug)
      if child_slug
        Category.where(slug: child_slug, parent_category_id: categories.select(:id)).first
      else
        categories.where(parent_category_id: nil).first
      end
    end
  end
end
