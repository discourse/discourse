# frozen_string_literal: true

module Chat
  class MentionNotices
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
end
