# frozen_string_literal: true

class DirectMessageUser < ActiveRecord::Base
  belongs_to :direct_message, foreign_key: :direct_message_channel_id
  belongs_to :user
end

# == Schema Information
#
# Table name: direct_message_users
#
#  id                        :bigint           not null, primary key
#  direct_message_channel_id :integer          not null
#  user_id                   :integer          not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  direct_message_users_index  (direct_message_channel_id,user_id) UNIQUE
#
