# frozen_string_literal: true

class ChatDraft < ActiveRecord::Base
  belongs_to :user
  belongs_to :chat_channel
end

# == Schema Information
#
# Table name: chat_drafts
#
#  id              :bigint           not null, primary key
#  user_id         :integer          not null
#  chat_channel_id :integer          not null
#  data            :text             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
