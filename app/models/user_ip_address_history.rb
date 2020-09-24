# frozen_string_literal: true

class UserIpAddressHistory < ActiveRecord::Base
  belongs_to :user

  validates :user_id, presence: true
  validates :ip_address, presence: true, uniqueness: { scope: :user_id }
end
