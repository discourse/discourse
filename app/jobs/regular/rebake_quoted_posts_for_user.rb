# frozen_string_literal: true

module Jobs
  class RebakeQuotedPostsForUser < ::Jobs::Base
    def execute(args)
      user_id = args[:user_id]
      return if user_id.blank?

      Post.rebake_all_quoted_posts(user_id)
    end
  end
end
