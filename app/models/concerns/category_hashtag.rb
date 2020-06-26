# frozen_string_literal: true

module CategoryHashtag
  extend ActiveSupport::Concern

  SEPARATOR = ":"

  class_methods do
    def query_from_hashtag_slug(category_slug)
      slug_path = category_slug.split(SEPARATOR)

      return nil if slug_path.empty? || slug_path.size > SiteSetting.max_category_nesting

      if SiteSetting.slug_generation_method == "encoded"
        slug_path.map! { |slug| CGI.escape(slug) }
      end

      last_category_id = nil

      slug_path.each do |slug|
        query = Category.select(:id).where(slug: slug)
        query = query.where(parent_category_id: last_category_id) if last_category_id.present?
        return nil if query.blank?
        last_category_id = query
      end

      Category.find_by_id(last_category_id)
    end
  end
end
