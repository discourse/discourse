# frozen_string_literal: true

module ::DiscourseDataExplorer
  class SmallPostWithExcerptSerializer < ApplicationSerializer
    attributes :id, :topic_id, :post_number, :excerpt, :username, :avatar_template

    def excerpt
      Post.excerpt(object.cooked, 70)
    end

    def username
      object.user && object.user.username
    end

    def avatar_template
      object.user && object.user.avatar_template
    end
  end
end
