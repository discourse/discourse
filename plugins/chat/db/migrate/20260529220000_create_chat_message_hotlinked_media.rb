# frozen_string_literal: true

class CreateChatMessageHotlinkedMedia < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_message_hotlinked_media, if_not_exists: true do |t|
      t.bigint :chat_message_id, null: false
      t.string :url, null: false
      t.string :status, null: false
      t.bigint :upload_id
      t.timestamps
    end

    # url can exceed the btree key limit, so index on its md5 digest.
    add_index :chat_message_hotlinked_media,
              "chat_message_id, md5(url)",
              unique: true,
              name: "index_chat_message_hotlinked_media_on_message_and_url_md5",
              if_not_exists: true
  end
end
