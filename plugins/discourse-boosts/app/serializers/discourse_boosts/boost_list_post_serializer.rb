# frozen_string_literal: true

module DiscourseBoosts
  class BoostListPostSerializer < ::ApplicationSerializer
    attributes :id,
               :url,
               :excerpt,
               :username,
               :name,
               :avatar_template,
               :user_id,
               :user_title,
               :primary_group_name,
               :topic_id,
               :topic_title,
               :category_id,
               :post_type

    def url
      object.url
    end

    def excerpt
      object.excerpt(300, strip_links: true, text_entities: true)
    end

    def username
      object.user.username
    end

    def name
      object.user.name
    end

    def avatar_template
      object.user.avatar_template
    end

    def topic_title
      object.topic.title
    end

    def user_title
      object&.user&.title
    end

    def primary_group_name
      object&.user&.primary_group&.name
    end

    def category_id
      object.topic.category_id
    end
  end
end
