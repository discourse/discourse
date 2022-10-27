# frozen_string_literal: true

class ChatUpload < ActiveRecord::Base
  belongs_to :chat_message
  belongs_to :upload
end

# == Schema Information
#
# Table name: chat_uploads
#
#  id              :bigint           not null, primary key
#  chat_message_id :integer          not null
#  upload_id       :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_chat_uploads_on_chat_message_id_and_upload_id  (chat_message_id,upload_id) UNIQUE
#
