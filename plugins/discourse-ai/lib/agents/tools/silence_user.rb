# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SilenceUser < Tool
        # ~100 years — an effectively permanent silence, while keeping
        # `duration_days.days.from_now` inside a representable time range.
        MAX_DURATION_DAYS = 36_500

        def self.signature
          {
            name: name,
            description:
              "Silences a user, blocking them from creating new posts/replies while they can still read the forum.",
            parameters: [
              {
                name: "username",
                description: "The username of the user to silence",
                type: "string",
                required: true,
              },
              {
                name: "duration_days",
                description:
                  "How many days to silence the user for. Use a very large number (e.g. 36500) for an effectively permanent silence.",
                type: "integer",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the user is being silenced",
                type: "string",
                required: true,
              },
              {
                name: "message",
                description: "Optional message sent to the user explaining the silence",
                type: "string",
              },
            ],
          }
        end

        def self.name
          "silence_user"
        end

        def self.requires_approval?
          true
        end

        def self.mandatory_approval?
          true
        end

        def self.attribute_to_approver?
          true
        end

        def invoke
          user = User.find_by_username(parameters[:username])
          if !user
            return error_response(I18n.t("discourse_ai.ai_bot.silence_user.errors.not_found"))
          end

          if !guardian.can_silence_user?(user)
            return error_response(I18n.t("discourse_ai.ai_bot.silence_user.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.silence_user.errors.no_reason"))
          end

          duration_days = Integer(parameters[:duration_days], exception: false)
          if duration_days.nil? || duration_days <= 0 || duration_days > MAX_DURATION_DAYS
            return(
              error_response(
                I18n.t(
                  "discourse_ai.ai_bot.silence_user.errors.invalid_duration",
                  max: MAX_DURATION_DAYS,
                ),
              )
            )
          end

          result =
            User::Silence.call(
              guardian: guardian,
              params: {
                user_id: user.id,
                reason: reason,
                silenced_till: duration_days.days.from_now,
                message: parameters[:message],
                reviewable_id: context.reviewable_id,
              },
            )

          return error_response(silence_error_message(result)) if result.failure?

          {
            status: "success",
            message: I18n.t("discourse_ai.ai_bot.silence_user.success", username: user.username),
          }
        end

        def description_args
          { username: parameters[:username], duration_days: parameters[:duration_days] }
        end

        private

        def silence_error_message(result)
          contract_result = result["result.contract.default"]
          return contract_result.errors.full_messages.to_sentence if contract_result&.failure?

          %i[not_silenced_already can_silence_all_users].each do |policy_name|
            policy_result = result["result.policy.#{policy_name}"]
            next if !policy_result&.failure?
            return policy_result.reason if policy_result.reason.present?
            return I18n.t("discourse_ai.ai_bot.silence_user.errors.failed")
          end

          I18n.t("discourse_ai.ai_bot.silence_user.errors.failed")
        end
      end
    end
  end
end
