# frozen_string_literal: true

module Jobs
  class CommitSharedRevision < ::Jobs::Base
    def execute(args)
      post_id = args[:post_id]
      Discourse.redis.del SharedEditRevision.will_commit_key(post_id)
      SharedEditRevision.commit!(post_id)
    end
  end
end
