# frozen_string_literal: true

module Chat
  class Draft < ActiveRecord::Base
    belongs_to :user
    belongs_to :chat_channel, class_name: "Chat::Channel"

    self.table_name = "chat_drafts"

    validate :data_length
    def data_length
      if self.data && self.data.length > SiteSetting.max_chat_draft_length
        self.errors.add(:base, I18n.t("chat.errors.draft_too_long"))
      end
    end
  end
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
