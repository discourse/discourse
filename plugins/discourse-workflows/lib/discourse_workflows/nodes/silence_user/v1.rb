# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module SilenceUser
      class V1 < NodeType
        include UserModerationAction

        NOT_ALLOWED_ERROR = "discourse_workflows.errors.user_moderation_action.silence_not_allowed"

        description(
          UserModerationAction.penalty_description(
            name: "action:silence_user",
            icon: "microphone-slash",
            end_field: :silenced_till,
            changed: "False when the user was already silenced, keeping that silence",
          ),
        )

        def self.validate_configuration(configuration, errors)
          validate_timezone_configuration(configuration, errors)
        end

        private

        # Through the admin silence modal's service, so the user's recent posts stay visible.
        def change_user(exec_ctx, item_index)
          actor, user = find_actor_and_user(exec_ctx, item_index)
          ensure_allowed!(actor.guardian.can_silence_user?(user), actor, user, item_index)

          silenced_till = penalty_end(exec_ctx, "silenced_till", item_index)
          params = penalty_params(exec_ctx, user, item_index)
          changed =
            !user.silenced? &&
              apply_penalty(
                ::User::Silence,
                actor,
                user,
                params.merge(silenced_till:),
                item_index,
                already: :not_silenced_already,
                allowed: :can_silence_all_users,
              )

          user.reload
          user_output(user, actor, changed:, expires_at: user.silenced_till.iso8601)
        end
      end
    end
  end
end
