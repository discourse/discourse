# frozen_string_literal: true

module DiscourseAi
  module AiBot
    # Bridges the ReviewableAiToolAction approval queue to the Chat plugin's
    # interactive "blocks", so a moderator can approve/reject a bot-requested
    # action inline in a chat conversation — mirroring the inline card used in
    # the bot's PM/topic replies. Scoped to bot direct-message channels.
    module ChatToolApproval
      ACTION_PREFIX = "ai_tool_approval"

      def self.build_action_id(action, reviewable_id)
        "#{ACTION_PREFIX}::#{action}::#{reviewable_id}"
      end

      def self.parse_action_id(raw)
        prefix, action, reviewable_id = raw.to_s.split("::")
        return if prefix != ACTION_PREFIX
        return if !%w[approve reject].include?(action)
        return if reviewable_id.to_i <= 0

        { action: action, reviewable_id: reviewable_id.to_i }
      end

      def self.pending_blocks(reviewable_id)
        [
          {
            type: "actions",
            schema_version: 1,
            elements: [
              {
                type: "button",
                schema_version: 1,
                action_id: build_action_id("approve", reviewable_id),
                style: "primary",
                text: {
                  type: "plain_text",
                  text: I18n.t("discourse_ai.reviewables.ai_tool_action.approve.title"),
                },
              },
              {
                type: "button",
                schema_version: 1,
                action_id: build_action_id("reject", reviewable_id),
                style: "danger",
                text: {
                  type: "plain_text",
                  text: I18n.t("discourse_ai.reviewables.ai_tool_action.reject.title"),
                },
              },
            ],
          },
        ]
      end

      # Handles a :chat_message_interaction event: performs the approval/
      # rejection and rewrites the message to its resolved state. Done inline
      # (not in a background job) so the buttons are cleared before the request
      # returns — the button is disabled while in flight, so this closes the
      # window for a double-click hitting an already-resolved message.
      def self.handle_interaction(interaction)
        return if interaction.blank?

        parsed = parse_action_id(interaction.action&.dig("action_id"))
        return if parsed.blank?

        reviewable = ReviewableAiToolAction.find_by(id: parsed[:reviewable_id])
        return if reviewable.blank? || !reviewable.pending?

        user = interaction.user
        return if user.blank?

        # Same authorization as the review queue: only users who can see this
        # reviewable may act on it. Everyone else is silently ignored.
        return if !Reviewable.viewable_by(user).exists?(id: reviewable.id)

        message = interaction.message

        begin
          reviewable.perform(user, parsed[:action].to_sym)
          status_key = parsed[:action] == "approve" ? "approved" : "rejected"
          resolve_message!(
            message,
            I18n.t("discourse_ai.ai_bot.chat_tool_approval.#{status_key}", username: user.username),
          )
        rescue => e
          # The reviewable stays pending; keep the buttons for a retry and
          # surface the reason. Never let the event handler raise — that would
          # 500 the interaction request.
          append_error!(
            message,
            I18n.t("discourse_ai.ai_bot.chat_tool_approval.failed", error: failure_reason(e)),
          )
        end
      end

      # Surfaces a user-facing reason for a failed action. Only the localized
      # messages our own flow raises (Discourse::InvalidAccess) are shown; any
      # other/unexpected exception falls back to a generic message so internal
      # error text is never leaked into the chat.
      def self.failure_reason(error)
        if error.is_a?(Discourse::InvalidAccess)
          if error.custom_message.present?
            return I18n.t(error.custom_message, error.custom_message_params || {})
          end
          return error.message if error.message.present?
        end

        I18n.t("discourse_ai.ai_bot.chat_tool_approval.unexpected_error")
      end

      # Appends the resolved status to the approval message and removes the
      # buttons so it can no longer be actioned.
      def self.resolve_message!(message, status_text)
        return if message.blank?

        message.message = "#{message.message}\n\n#{status_text}"
        message.blocks = nil
        message.cook
        message.save!
        ::Chat::Publisher.publish_edit!(message.chat_channel, message.reload)
      end

      # Keeps the buttons in place (so a permitted moderator can retry) but
      # surfaces why the action could not be completed.
      def self.append_error!(message, status_text)
        return if message.blank?

        message.message = "#{message.message}\n\n#{status_text}"
        message.cook
        message.save!
        ::Chat::Publisher.publish_edit!(message.chat_channel, message.reload)
      end
    end
  end
end
