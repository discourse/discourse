# frozen_string_literal: true
#
class AddIconUploadIdToChatChannel < ActiveRecord::Migration[7.1]
  def change
    add_column :chat_channels, :icon_upload_id, :integer
  end
end
