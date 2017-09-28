# This job will automatically act on records that have gone unhandled on a
# queue for a long time.
module Jobs
  class AutoQueueHandler < Jobs::Scheduled

    every 1.day

    def execute(args)
      return unless SiteSetting.auto_handle_queued_age.to_i > 0

      guardian = Guardian.new(Discourse.system_user)

      # Flags
      flags = FlagQuery.flagged_post_actions(filter: 'active')
        .where('post_actions.created_at < ?', SiteSetting.auto_handle_queued_age.to_i.days.ago)

      Post.where(id: flags.pluck(:post_id).uniq).each do |post|
        PostAction.defer_flags!(post, Discourse.system_user)
      end

      # Posts
      queued_posts = QueuedPost.visible
        .where(state: QueuedPost.states[:new])
        .where('created_at < ?', SiteSetting.auto_handle_queued_age.to_i.days.ago)

      queued_posts.each do |queued_post|
        queued_post.reject!(Discourse.system_user)
      end
    end
  end
end
