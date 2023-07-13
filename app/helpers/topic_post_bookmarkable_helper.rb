# frozen_string_literal: true

module TopicPostBookmarkableHelper
  extend ActiveSupport::Concern

  module ClassMethods
    def sync_topic_user_bookmarked(user, topic, opts)
      return if opts.key?(:auto_track) && !opts[:auto_track]
      TopicUser.change(
        user.id,
        topic.id,
        bookmarked: Bookmark.for_user_in_topic(user.id, topic).exists?,
      )
    end
  end
end
