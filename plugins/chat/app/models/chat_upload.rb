# frozen_string_literal: true

# TODO (martin) DEPRECATED: Remove this model once UploadReference has been
# in place for a couple of months, 2023-04-01
#
# NOTE: Do not use this model anymore, chat messages are linked to uploads via
# the UploadReference table now, just like everything else.
class ChatUpload < ActiveRecord::Base
  belongs_to :chat_message
  belongs_to :upload

  deprecate *public_instance_methods(false)
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
