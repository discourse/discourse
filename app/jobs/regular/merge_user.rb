# frozen_string_literal: true

module Jobs
  class MergeUser < ::Jobs::Base
    def execute(args)
      target_user_id = args[:target_user_id]
      current_user_id = args[:current_user_id]

      user = User.find_by(id: args[:user_id])
      target_user = User.find_by(id: args[:target_user_id])
      current_user = User.find_by(id: args[:current_user_id])
      guardian = Guardian.new(current_user)
      serializer_opts = { root: false, scope: guardian }

      if user = UserMerger.new(user, target_user, current_user).merge!
        user_json = AdminDetailedUserSerializer.new(user, serializer_opts).as_json
        ::MessageBus.publish "/merge_user",
                             { success: "OK" }.merge(merged: true, user: user_json),
                             user_ids: [current_user.id]
      else
        ::MessageBus.publish "/merge_user",
                             { failed: "FAILED" }.merge(
                               user:
                                 AdminDetailedUserSerializer.new(@user, serializer_opts).as_json,
                             ),
                             user_ids: [current_user.id]
      end
    end
  end
end
