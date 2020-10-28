# frozen_string_literal: true

class UserIpAddressHistory < ActiveRecord::Base
  belongs_to :user

  validates :user_id, presence: true
  validates :ip_address, presence: true, uniqueness: { scope: :user_id }
end

# == Schema Information
#
# Table name: user_ip_address_histories
#
#  id         :bigint           not null, primary key
#  user_id    :integer          not null
#  ip_address :inet             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_user_ip_address_histories_on_user_id_and_ip_address  (user_id,ip_address) UNIQUE
#
