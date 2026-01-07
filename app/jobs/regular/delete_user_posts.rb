# frozen_string_literal: true

module Jobs
  class DeleteUserPosts < ::Jobs::Base
    sidekiq_options queue: "critical"

    def execute(args)
      user = User.find(args[:user_id])
      acting_user = User.find(args[:acting_user_id]) if args[:acting_user_id]

      guardian = Guardian.new(acting_user)
      raise Discourse::InvalidAccess unless guardian.can_delete_all_posts?(user)

      deleted_count = 0

      loop do
        delete = user.delete_posts_in_batches(guardian)
        break if delete.empty?
        deleted_count += delete.size
      end

      post =
        SystemMessage.create_from_system_user(
          acting_user,
          :user_posts_deleted,
          user: user.username,
          staff_user: acting_user.username,
          deleted_posts_count: deleted_count,
        )

      post&.topic&.invite_group(acting_user, Group[:admins])
    end
  end
end
