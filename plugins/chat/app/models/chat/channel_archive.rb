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
      archived_messages >= total_messages && chat_channel.chat_messages.count.zero?
    end

    def failed?
      !complete? && archive_error.present?
    end

    def new_topic?
      destination_topic_title.present?
    end
  end
end

# == Schema Information
#
# Table name: chat_channel_archives
#
#  id                      :bigint           not null, primary key
#  archive_error           :string
#  archived_messages       :integer          default(0), not null
#  destination_tags        :string           is an Array
#  destination_topic_title :string
#  total_messages          :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  archived_by_id          :integer          not null
#  chat_channel_id         :bigint           not null
#  destination_category_id :integer
#  destination_topic_id    :integer
#
# Indexes
#
#  index_chat_channel_archives_on_chat_channel_id  (chat_channel_id)
#
