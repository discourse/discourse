# frozen_string_literal: true

module DiscourseWorkflows
  class TopicListItemSerializer < ::TopicListItemSerializer
    attributes :user_id, :username, :url

    def username
      object.user&.username
    end

    def include_first_post_id?
      true
    end

    def first_post_id
      object.first_post&.id
    end

    def include_fancy_title_localized?
      true
    end

    def include_locale?
      true
    end
  end
end
