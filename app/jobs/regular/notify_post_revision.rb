# frozen_string_literal: true

module Jobs
  class NotifyPostRevision < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:user_ids) unless args[:user_ids]

      post_revision = PostRevision.find_by(id: args[:post_revision_id])
      raise Discourse::InvalidParameters.new(:post_revision_id) unless post_revision

      ActiveRecord::Base.transaction do
        User.where(id: args[:user_ids]).find_each do |user|
          next if post_revision.hidden && !user.staff?

          PostActionNotifier.alerter.create_notification(
            user,
            Notification.types[:edited],
            post_revision.post,
            display_username: post_revision.user.username,
            acting_user_id: post_revision&.user_id,
            revision_number: post_revision.number
          )
        end
      end
    end
  end
end
