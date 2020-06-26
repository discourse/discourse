# frozen_string_literal: true

module CategoryHashtag
  extend ActiveSupport::Concern

  SEPARATOR = ":"

  class_methods do
    def query_from_hashtag_slug(category_slug)
      slug_path = category_slug.split(SEPARATOR)
      Category.find_by_slug_path(slug_path)
    end
  end
end
