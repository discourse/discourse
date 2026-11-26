# frozen_string_literal: true

module ::Blog
  class InstanceSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :slug,
               :url,
               :description,
               :about,
               :category_id,
               :path_format,
               :posts_per_page,
               :is_default,
               :published,
               :base_url,
               :problems,
               :can_delete,
               :slug_locked,
               :category_locked,
               :active_theme

    def base_url
      Configuration.base_url(object)
    end

    def problems
      Readiness.new(object).problems.map(&:message)
    end

    # The caller counts every blog's articles in one query, trashed ones included.
    def can_delete
      !object.is_default? && @options[:article_counts].fetch(object.id, 0).zero?
    end

    def slug_locked
      object.slug_locked?
    end

    def category_locked
      object.category_locked?
    end

    def active_theme
      BlogTheme.active_for(object).slice("id", "name", "revision", "preset")
    end
  end
end
