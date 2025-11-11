# frozen_string_literal: true

module Chat
  class NullMessage < Chat::Message
    def user
      nil
    end

    def build_excerpt
      nil
    end

    def id
      nil
    end

    def created_at
      Time.now # a proper NullTime object would be better, but this is good enough for now
    end
  end
end

# == Schema Information
#
# Table name: chat_messages
#
#  id              :bigint           not null, primary key
#  chat_channel_id :bigint           not null
#  user_id         :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  deleted_at      :datetime
#  deleted_by_id   :integer
#  in_reply_to_id  :bigint
#  message         :text
#  cooked          :text
#  cooked_version  :integer
#  last_editor_id  :integer          not null
#  thread_id       :bigint
#  streaming       :boolean          default(FALSE), not null
#  excerpt         :string(1000)
#  created_by_sdk  :boolean          default(FALSE), not null
#  blocks          :jsonb
#
# Indexes
#
#  idx_chat_messages_by_created_at_not_deleted            (created_at) WHERE (deleted_at IS NULL)
#  idx_chat_messages_by_thread_id_not_deleted             (thread_id) WHERE (deleted_at IS NULL)
#  index_chat_messages_on_chat_channel_id_and_created_at  (chat_channel_id,created_at)
#  index_chat_messages_on_chat_channel_id_and_id          (chat_channel_id,id) WHERE (deleted_at IS NOT NULL)
#  index_chat_messages_on_last_editor_id                  (last_editor_id)
#  index_chat_messages_on_thread_id                       (thread_id)
#
