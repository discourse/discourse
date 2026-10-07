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

      def self.format_value(value)
        text = value.to_s
        text = I18n.t("discourse_ai.ai_bot.chat_tool_approval.empty_value") if text.empty?
        longest_run = text.scan(/`+/).map(&:length).max.to_i

        if text.include?("\n")
          fence = "`" * [3, longest_run + 1].max
          "\n#{fence}\n#{text}\n#{fence}\n"
        else
          delimiter = "`" * (longest_run + 1)
          "#{delimiter} #{text} #{delimiter}"
        end
      end

      def self.format_topic(topic)
        format_link(topic.title, topic.url)
      end

      def self.format_link(text, url)
        title = CGI.escapeHTML(text).gsub(/[\\`*_\[\]]/) { |character| "\\#{character}" }
        "[#{title}](#{url})"
      end

      def self.pending_blocks(reviewable_id, info: nil)
        [
          {
            type: info ? "confirmation" : "actions",
            schema_version: 1,
            **(
              if info
                {
                  title: info[:summary],
                  **(
                    info[:description_label] ? { description_label: info[:description_label] } : {}
                  ),
                  show_description: info.fetch(:show_description, true),
                  question: info[:question],
                  parameters: info[:parameters],
                  changes: info[:changes] || [],
                }
              else
                {}
              end
            ),
            elements: [
              {
                type: "button",
                schema_version: 1,
                action_id: build_action_id("approve", reviewable_id),
                style: "default",
                text: {
                  type: "plain_text",
                  text: I18n.t("discourse_ai.ai_bot.chat_tool_approval.approve_label"),
                },
              },
              {
                type: "button",
                schema_version: 1,
                action_id: build_action_id("reject", reviewable_id),
                style: "default",
                text: {
                  type: "plain_text",
                  text: I18n.t("discourse_ai.ai_bot.chat_tool_approval.reject_label"),
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
          reviewable.perform(user, parsed[:action].to_sym, chat_message_id: message.id)
          status_key = parsed[:action] == "approve" ? "approved" : "rejected"
          resolve_message!(
            message,
            I18n.t("discourse_ai.ai_bot.chat_tool_approval.#{status_key}", username: user.username),
            title: parsed[:action] == "approve" ? resolved_title(reviewable) : nil,
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

      def self.resolved_title(reviewable)
        action = reviewable.target
        return if action.tool_name != "edit_tag" || action.tool_parameters["new_name"].blank?

        name = DiscourseTagging.clean_tag(action.tool_parameters["new_name"].to_s)
        tag = Tag.where_name(name).first
        return if tag.blank?

        I18n.t("discourse_ai.ai_bot.chat_tool_approval.tag_title", tag: "##{tag.name}::tag")
      end

      def self.resolve_message!(message, status_text, title: nil)
        return if message.blank?

        if (card = message.blocks&.find { |block| block["type"] == "confirmation" })
          card["title"] = title if title
          card.delete("error")
          card["status"] = status_text
          card["elements"] = []
          card["parameters"].reject! { |parameter| parameter["label"] == "reason" }
        else
          message.message = "#{message.message}\n\n#{status_text}"
          message.blocks = nil
        end
        message.cook
        message.save!
        ::Chat::Publisher.publish_edit!(message.chat_channel, message.reload)
      end

      # Keeps the buttons in place (so a permitted moderator can retry) but
      # surfaces why the action could not be completed.
      def self.append_error!(message, status_text)
        return if message.blank?

        if (card = message.blocks&.find { |block| block["type"] == "confirmation" })
          card["error"] = status_text
        else
          message.message = "#{message.message}\n\n#{status_text}"
        end
        message.cook
        message.save!
        ::Chat::Publisher.publish_edit!(message.chat_channel, message.reload)
      end
    end
  end
end
