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
               :topic_id,
               :topic_title

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
  end
end
