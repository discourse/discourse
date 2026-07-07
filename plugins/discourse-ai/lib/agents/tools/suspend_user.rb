# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SuspendUser < Tool
        def self.signature
          {
            name: name,
            description:
              "Suspends (bans) a user, fully blocking them from logging in or posting until the suspension ends.",
            parameters: [
              {
                name: "username",
                description: "The username of the user to suspend/ban",
                type: "string",
                required: true,
              },
              {
                name: "duration_days",
                description:
                  "How many days to suspend the user for. Use a very large number (e.g. 36500) for a permanent ban.",
                type: "integer",
                required: true,
              },
              {
                name: "reason",
                description: "Short explanation of why the user is being suspended/banned",
                type: "string",
                required: true,
              },
              {
                name: "message",
                description: "Optional message sent to the user explaining the suspension",
                type: "string",
              },
            ],
          }
        end

        def self.name
          "suspend_user"
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
            return error_response(I18n.t("discourse_ai.ai_bot.suspend_user.errors.not_found"))
          end

          if !guardian.can_suspend?(user)
            return error_response(I18n.t("discourse_ai.ai_bot.suspend_user.errors.not_allowed"))
          end

          if reason.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.suspend_user.errors.no_reason"))
          end

          duration_days = Integer(parameters[:duration_days], exception: false)
          if duration_days.nil? || duration_days <= 0
            return(
              error_response(I18n.t("discourse_ai.ai_bot.suspend_user.errors.invalid_duration"))
            )
          end

          result =
            User::Suspend.call(
              guardian: guardian,
              params: {
                user_id: user.id,
                reason: reason,
                suspend_until: duration_days.days.from_now,
                message: parameters[:message],
                reviewable_id: context.reviewable_id,
              },
            )

          return error_response(suspend_error_message(result)) if result.failure?

          {
            status: "success",
            message: I18n.t("discourse_ai.ai_bot.suspend_user.success", username: user.username),
          }
        end

        def description_args
          { username: parameters[:username], duration_days: parameters[:duration_days] }
        end

        private

        def suspend_error_message(result)
          contract_result = result["result.contract.default"]
          return contract_result.errors.full_messages.to_sentence if contract_result&.failure?

          %i[not_suspended_already can_suspend_all_users].each do |policy_name|
            policy_result = result["result.policy.#{policy_name}"]
            next if !policy_result&.failure?
            return policy_result.reason if policy_result.reason.present?
            return I18n.t("discourse_ai.ai_bot.suspend_user.errors.failed")
          end

          I18n.t("discourse_ai.ai_bot.suspend_user.errors.failed")
        end
      end
    end
  end
end
