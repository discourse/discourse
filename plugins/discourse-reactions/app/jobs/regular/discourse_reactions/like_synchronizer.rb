# frozen_string_literal: true

module Jobs
  module DiscourseReactions
    class LikeSynchronizer < ::Jobs::Base
      cluster_concurrency 1

      def execute(args = {})
        if !SiteSetting.discourse_reactions_enabled ||
             !SiteSetting.discourse_reactions_like_sync_enabled
          return
        end

        ::DiscourseReactions::ReactionLikeSynchronizer.sync!
      end
    end
  end
end
