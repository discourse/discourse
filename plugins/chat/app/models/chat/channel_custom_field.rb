# frozen_string_literal: true

module Chat
  class ChannelCustomField < ActiveRecord::Base
    belongs_to :channel
  end
end

# == Schema Information
#
# Table name: chat_channel_custom_fields
#
#  id              :bigint           not null, primary key
#  chat_channel_id :bigint           not null
#  name            :string(256)      not null
#  value           :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_chat_channel_custom_fields_on_chat_channel_id  (chat_channel_id)
#
