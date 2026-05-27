# frozen_string_literal: true

module Jobs
  class DeleteUserPosts < ::Jobs::Base
    sidekiq_options queue: "critical"

    def execute(args)
      user = User.find_by(id: args[:user_id])
      return if user.nil?

      acting_user = User.find_by(id: args[:acting_user_id])
      return if acting_user.nil?

      guardian = Guardian.new(acting_user)
      return unless guardian.can_delete_all_posts?(user)

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
          count: deleted_count,
        )

      post&.topic&.invite_group(acting_user, Group[:admins])
    end
  end
end
