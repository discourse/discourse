# frozen_string_literal: true

module Chat
  class ChannelArchive < ActiveRecord::Base
    belongs_to :chat_channel, class_name: "Chat::Channel"
    belongs_to :archived_by, class_name: "User"
    belongs_to :destination_topic, class_name: "Topic"

    validates :archive_error, length: { maximum: 1000 }
    validates :destination_topic_title, length: { maximum: 1000 }

    self.table_name = "chat_channel_archives"

    def complete?
      self.archived_messages >= self.total_messages && self.chat_channel.chat_messages.count.zero?
    end

    def failed?
      !complete? && self.archive_error.present?
    end

    def new_topic?
      self.destination_topic_title.present?
    end
  end
end

# == Schema Information
#
# Table name: chat_channel_archives
#
#  id                      :bigint           not null, primary key
#  chat_channel_id         :bigint           not null
#  archived_by_id          :integer          not null
#  destination_topic_id    :integer
#  destination_topic_title :string
#  destination_category_id :integer
#  destination_tags        :string           is an Array
#  total_messages          :integer          not null
#  archived_messages       :integer          default(0), not null
#  archive_error           :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_chat_channel_archives_on_chat_channel_id  (chat_channel_id)
#
