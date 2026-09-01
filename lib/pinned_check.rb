# frozen_string_literal: true

# Helps us determine whether a topic should be displayed as pinned or not,
# taking into account anonymous users and users who have dismissed it
class PinnedCheck
  class << self
    def unpinned?(topic, topic_user = nil)
      topic.pinned_at && topic_user && topic_user.cleared_pinned_at &&
        topic_user.cleared_pinned_at > topic.pinned_at
    end

    def pinned?(topic, topic_user = nil)
      !!topic.pinned_at && !unpinned?(topic, topic_user)
    end
  end
end
