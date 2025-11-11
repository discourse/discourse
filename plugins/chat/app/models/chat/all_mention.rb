# frozen_string_literal: true

module Chat
  class AllMention < Mention
  end
end

# == Schema Information
#
# Table name: chat_mentions
#
#  id              :bigint           not null, primary key
#  chat_message_id :bigint           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  type            :string           not null
#  target_id       :integer
#
# Indexes
#
#  index_chat_mentions_on_chat_message_id  (chat_message_id)
#  index_chat_mentions_on_target_id        (target_id)
#
