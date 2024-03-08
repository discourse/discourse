# frozen_string_literal: true

module Chat
  class MentionsWarnings
    def self.send_for(message)
      @message = message
      parsed_mentions = message.parsed_mentions
      users_to_send_invitation_to_channel = parsed_mentions.users_to_send_invitation_to_channel
      users_who_cannot_join_channel = parsed_mentions.users_who_cannot_join_channel
      groups_with_too_many_members = parsed_mentions.groups_with_too_many_members
      groups_with_disabled_mentions = parsed_mentions.groups_with_disabled_mentions

      unless users_to_send_invitation_to_channel.empty?
        warn(
          Warnings.users_do_not_participate_in_channel(
            users_to_send_invitation_to_channel,
            message.id,
          ),
        )
      end

      unless users_who_cannot_join_channel.empty?
        warn(Warnings.users_cannot_join_channel(users_who_cannot_join_channel))
      end

      unless groups_with_too_many_members.empty?
        warn(Warnings.groups_have_too_many_members(groups_with_too_many_members))
      end

      unless groups_with_disabled_mentions.empty?
        warn(Warnings.groups_have_mentions_disabled(groups_with_disabled_mentions))
      end

      if parsed_mentions.has_mass_mention && !message.chat_channel.allow_channel_wide_mentions
        warn(Warnings.global_mentions_disabled)
      end
    end

    private

    def self.warn(params)
      ::Chat::Publisher.publish_notice(
        user_id: @message.user.id,
        channel_id: @message.chat_channel.id,
        **params,
      )
    end

    class Warnings
      def self.global_mentions_disabled
        warning = I18n.t("chat.mention_warning.global_mentions_disallowed")
        { text_content: warning }
      end

      def self.groups_have_mentions_disabled(groups)
        warning =
          warning_text(
            single: "chat.mention_warning.group_mentions_disabled",
            multiple: "chat.mention_warning.group_mentions_disabled_multiple",
            first_identifier: groups.first.name,
            count: groups.count,
          )

        { text_content: warning }
      end

      def self.groups_have_too_many_members(groups)
        warning =
          warning_text(
            single: "chat.mention_warning.too_many_members",
            multiple: "chat.mention_warning.too_many_members_multiple",
            first_identifier: groups.first.name,
            count: groups.count,
          )

        { text_content: warning }
      end

      def self.users_cannot_join_channel(users)
        warning =
          warning_text(
            single: "chat.mention_warning.cannot_see",
            multiple: "chat.mention_warning.cannot_see_multiple",
            first_identifier: users.first.username,
            count: users.count,
          )

        { text_content: warning }
      end

      def self.users_do_not_participate_in_channel(users, message_id)
        warning =
          warning_text(
            single: "chat.mention_warning.without_membership",
            multiple: "chat.mention_warning.without_membership_multiple",
            first_identifier: users.first.username,
            count: users.count,
          )

        {
          type: "mention_without_membership",
          data: {
            user_ids: users.map(&:id),
            text: warning,
            message_id: message_id,
          },
        }
      end

      private

      def self.warning_text(single:, multiple:, first_identifier:, count:)
        translation_key = count == 1 ? single : multiple
        I18n.t(translation_key, first_identifier: first_identifier, count: count - 1)
      end

      private_class_method :warning_text
    end

    private_constant :Warnings
    private_class_method :warn
  end
end
