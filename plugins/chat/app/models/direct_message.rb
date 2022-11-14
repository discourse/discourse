# frozen_string_literal: true

class DirectMessage < ActiveRecord::Base
  self.table_name = "direct_message_channels"

  include Chatable

  has_many :direct_message_users, foreign_key: :direct_message_channel_id
  has_many :users, through: :direct_message_users

  def self.for_user_ids(user_ids)
    joins(:users)
      .group("direct_message_channels.id")
      .having("ARRAY[?] = ARRAY_AGG(users.id ORDER BY users.id)", user_ids.sort)
      &.first
  end

  def user_can_access?(user)
    users.include?(user)
  end

  def chat_channel_title_for_user(chat_channel, acting_user)
    users =
      (direct_message_users.map(&:user) - [acting_user]).map { |user| user || DeletedChatUser.new }

    # direct message to self
    if users.empty?
      return I18n.t("chat.channel.dm_title.single_user", user: "@#{acting_user.username}")
    end

    # all users deleted
    return chat_channel.id if !users.first

    usernames_formatted = users.sort_by(&:username).map { |u| "@#{u.username}" }
    if usernames_formatted.size > 5
      return(
        I18n.t(
          "chat.channel.dm_title.multi_user_truncated",
          users: usernames_formatted[0..4].join(", "),
          leftover: usernames_formatted.length - 5,
        )
      )
    end

    I18n.t("chat.channel.dm_title.multi_user", users: usernames_formatted.join(", "))
  end
end

# == Schema Information
#
# Table name: direct_message_channels
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
