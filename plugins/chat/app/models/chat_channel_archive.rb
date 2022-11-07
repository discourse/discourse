# frozen_string_literal: true

class ChatChannelArchive < ActiveRecord::Base
  belongs_to :chat_channel
  belongs_to :archived_by, class_name: "User"

  belongs_to :destination_topic, class_name: "Topic"

  def complete?
    self.archived_messages >= self.total_messages && self.chat_channel.chat_messages.count.zero?
  end

  def failed?
    !complete? && self.archive_error.present?
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
