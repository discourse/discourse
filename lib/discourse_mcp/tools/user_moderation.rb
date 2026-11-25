# frozen_string_literal: true

module DiscourseMcp
  module Tools
    module UserModerationSupport
      MAX_DURATION_DAYS = 36_500
      OUTPUT_SCHEMA =
        OutputSchema.object(
          operation: OutputSchema::STRING,
          changed: OutputSchema::BOOLEAN,
          user: OutputSchema::OBJECT,
          actor: OutputSchema::OBJECT,
        )

      module_function

      def call(arguments, request_context, operation)
        guardian = request_context.guardian
        guardian.ensure_is_staff!
        user = User.find_by_username(arguments.fetch("username"))
        raise ToolError, I18n.t("mcp.errors.moderation_user_not_found") unless user
        permission = {
          "suspend" => :can_suspend?,
          "unsuspend" => :can_unsuspend?,
          "silence" => :can_silence_user?,
          "unsilence" => :can_unsilence_user?,
        }.fetch(operation)
        unless arguments["confirm"] == true
          raise ToolError, I18n.t("mcp.errors.moderation_confirmation_required")
        end
        # The custom message is sent to the user as a personal message.
        if arguments["message"].present? && ToolHelpers.private_messages_denied?(request_context)
          raise ToolError, I18n.t("mcp.errors.content_policy_blocked")
        end

        user.with_lock do
          raise Discourse::InvalidAccess unless guardian.public_send(permission, user)
          before = state(user)
          if %w[suspend silence].include?(operation)
            apply_restriction(user, guardian, arguments, operation)
          elsif operation == "unsuspend"
            UserSuspender.unsuspend(user, by_user: guardian.user)
          elsif user.silenced_till.present?
            UserSilencer.unsilence(user, guardian.user)
          end
          user.reload
          verified =
            (
              if operation.start_with?("un")
                !user.public_send(operation == "unsuspend" ? :suspended? : :silenced?)
              else
                user.public_send(operation == "suspend" ? :suspended? : :silenced?)
              end
            )
          raise ToolError, I18n.t("mcp.errors.moderation_operation_failed") unless verified

          after = state(user)
          ToolHelpers.text_and_structured(
            operation: operation,
            changed: before != after,
            user: after,
            actor: {
              id: guardian.user.id,
              username: guardian.user.username,
            },
          )
        end
      end

      def state(user)
        {
          id: user.id,
          username: user.username,
          suspended: user.suspended?,
          suspended_at: user.suspended_at&.iso8601,
          suspended_till: user.suspended_till&.iso8601,
          silenced: user.silenced?,
          silenced_at: user.silenced_at&.iso8601,
          silenced_till: user.silenced_till&.iso8601,
        }
      end

      def apply_restriction(user, guardian, arguments, operation)
        days = arguments["duration_days"]
        reason = arguments["reason"].to_s.strip
        unless days.is_a?(Integer) && days.between?(1, MAX_DURATION_DAYS) && reason.present? &&
                 reason.length <= 300
          raise ToolError,
                I18n.t("mcp.errors.moderation_invalid_duration_reason", max: MAX_DURATION_DAYS)
        end
        service = operation == "suspend" ? User::Suspend : User::Silence
        until_key = operation == "suspend" ? :suspend_until : :silenced_till
        result =
          service.call(
            guardian: guardian,
            params: {
              :user_id => user.id,
              :reason => reason,
              :message => arguments["message"],
              until_key => days.days.from_now,
            },
            options: {
              raise_on_failure: true,
            },
          )
        return if result.success?

        permission = operation == "suspend" ? :can_suspend_all_users : :can_silence_all_users
        raise Discourse::InvalidAccess if result["result.policy.#{permission}"]&.failure?
        contract = result["result.contract.default"]
        raise ToolError, contract.errors.full_messages.to_sentence if contract&.failure?
        policy =
          result["result.policy.not_#{operation == "suspend" ? "suspended" : "silenced"}_already"]
        raise ToolError, policy.reason if policy&.failure? && policy.reason.present?
        raise ToolError, I18n.t("mcp.errors.moderation_operation_failed")
      end
    end

    class SuspendUser
      REQUIRED_SCOPES = [Scopes::MODERATION_WRITE].freeze
      CONTENT = {
        topics: :unenforced,
        private_messages: :enforced,
        categories: :unenforced,
        tags: :unenforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = UserModerationSupport::OUTPUT_SCHEMA

      def self.call(arguments:, request_context:)
        UserModerationSupport.call(arguments, request_context, "suspend")
      end
    end

    class UnsuspendUser
      REQUIRED_SCOPES = [Scopes::MODERATION_WRITE].freeze
      CONTENT = {
        topics: :unenforced,
        private_messages: :enforced,
        categories: :unenforced,
        tags: :unenforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = UserModerationSupport::OUTPUT_SCHEMA

      def self.call(arguments:, request_context:)
        UserModerationSupport.call(arguments, request_context, "unsuspend")
      end
    end

    class SilenceUser
      REQUIRED_SCOPES = [Scopes::MODERATION_WRITE].freeze
      CONTENT = {
        topics: :unenforced,
        private_messages: :enforced,
        categories: :unenforced,
        tags: :unenforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = UserModerationSupport::OUTPUT_SCHEMA

      def self.call(arguments:, request_context:)
        UserModerationSupport.call(arguments, request_context, "silence")
      end
    end

    class UnsilenceUser
      REQUIRED_SCOPES = [Scopes::MODERATION_WRITE].freeze
      CONTENT = {
        topics: :unenforced,
        private_messages: :enforced,
        categories: :unenforced,
        tags: :unenforced,
        exit_paths: :untouched,
      }.freeze
      OUTPUT_SCHEMA = UserModerationSupport::OUTPUT_SCHEMA

      def self.call(arguments:, request_context:)
        UserModerationSupport.call(arguments, request_context, "unsilence")
      end
    end
  end
end
