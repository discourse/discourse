# frozen_string_literal: true

module Chat
  class MessageCustomField < ActiveRecord::Base
    belongs_to :message
  end
end

# == Schema Information
#
# Table name: chat_message_custom_fields
#
#  id         :bigint           not null, primary key
#  message_id :bigint           not null
#  name       :string(256)      not null
#  value      :string(1000000)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_chat_message_custom_fields_on_message_id_and_name  (message_id,name) UNIQUE
#
