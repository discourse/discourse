# frozen_string_literal: true

module DiscourseTemplates
  class TemplatesSerializer < ApplicationSerializer
    attributes :id, :title, :slug, :content, :tags, :usages

    def content
      object.first_post.raw
    end

    def include_tags?
      SiteSetting.tagging_enabled
    end

    def tags
      object.tags.map(&:name).sort
    end

    def usages
      object.template_item_usage_count
    end
  end
end
