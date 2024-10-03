# frozen_string_literal: true

module Chat
  class DirectMessage < ActiveRecord::Base
    self.table_name = "direct_message_channels"

    include Chatable
    include TypeMappable

    has_many :direct_message_users,
             class_name: "Chat::DirectMessageUser",
             foreign_key: :direct_message_channel_id
    has_many :users, through: :direct_message_users

    has_one :direct_message_channel, as: :chatable, class_name: "Chat::DirectMessageChannel"

    class << self
      def polymorphic_class_mapping = { "DirectMessage" => Chat::DirectMessage }

      def for_user_ids(user_ids, group: false)
        joins(:users)
          .where(group: group)
          .group("direct_message_channels.id")
          .having("ARRAY[?] = ARRAY_AGG(users.id ORDER BY users.id)", user_ids.sort)
          .first
      end
    end

    def user_can_access?(user)
      users.include?(user)
    end

    def chat_channel_title_for_user(chat_channel, acting_user)
      return chat_channel.name if group && chat_channel.name.present?

      users =
        (direct_message_users.map(&:user) - [acting_user])
          .map { |user| user || Chat::NullUser.new }
          .reject { |u| u.is_system_user? }

      prefers_name =
        SiteSetting.enable_names && SiteSetting.display_name_on_posts &&
          !SiteSetting.prioritize_username_in_ux

      # direct message to self
      if users.empty?
        return(
          I18n.t(
            "chat.channel.dm_title.single_user",
            username:
              (
                if prefers_name
                  acting_user.name.presence || acting_user.username
                else
                  acting_user.username
                end
              ),
          )
        )
      end

      # all users deleted
      return chat_channel.id if !users.first

      formatted_names =
        (
          if prefers_name
            users.map { |u| u.name.presence || u.username }.sort_by { |name| name[1..-1] }
          else
            users.map(&:username).sort
          end
        )

      if formatted_names.size > 7
        return(
          I18n.t(
            "chat.channel.dm_title.multi_user_truncated",
            comma_separated_usernames: formatted_names[0..5].join(I18n.t("word_connector.comma")),
            count: formatted_names.length - 6,
          )
        )
      end

      I18n.t(
        "chat.channel.dm_title.multi_user",
        comma_separated_usernames: formatted_names.join(I18n.t("word_connector.comma")),
      )
    end
  end
end

# == Schema Information
#
# Table name: direct_message_channels
#
#  id         :bigint           not null, primary key
#  group      :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
