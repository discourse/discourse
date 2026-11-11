# frozen_string_literal: true

class Chat::DiscoverableBot < ActiveRecord::Base
  self.table_name = "chat_discoverable_bots"

  belongs_to :user
end

# == Schema Information
#
# Table name: chat_discoverable_bots
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_chat_discoverable_bots_on_user_id  (user_id) UNIQUE
#
