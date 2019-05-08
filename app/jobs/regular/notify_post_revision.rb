module Jobs
  class NotifyPostRevision < Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      raise Discourse::InvalidParameters.new(:user_id) unless user

      post_revision = PostRevision.find_by(id: args[:post_revision_id])
      raise Discourse::InvalidParameters.new(:post_revision_id) unless post_revision

      PostActionNotifier.alerter.create_notification(
        user,
        Notification.types[:edited],
        post_revision.post,
        display_username: post_revision.user.username,
        acting_user_id: post_revision.try(:user_id),
        revision_number: post_revision.number
      )
    end
  end
end
