# frozen_string_literal: true

module Jobs
  class DeleteUserPosts < ::Jobs::Base
    sidekiq_options queue: "critical"

    def execute(args)
      user = User.find(args[:user_id])
      admin_user = User.find(args[:admin_id]) if args[:admin_id]

      raise Discourse::InvalidAccess unless admin_user&.admin?

      guardian = Guardian.new(admin_user)

      raise Discourse::InvalidAccess unless guardian.can_delete_all_posts?(user)

      deleted_count = 0

      loop do
        delete = user.delete_posts_in_batches(guardian)
        break if delete.empty?
        deleted_count += delete.size
      end

      post =
        SystemMessage.create_from_system_user(
          admin_user,
          :user_posts_deleted,
          user: user.username,
          staff_user: admin_user.username,
          deleted_posts_count: deleted_count,
        )

      post.topic.invite_group(admin_user, Group[:admins])
    end
  end
end
