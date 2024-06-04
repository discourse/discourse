# frozen_string_literal: true

class UserPassword < ActiveRecord::Base
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: :expired_at }, if: -> { expired_at.nil? }
  validates :hash, presence: true, length: { is: 64 }
  validates :salt, presence: true, length: { is: 32 }
  validates :algorithm, presence: true, length: { maximum: 64 }

  belongs_to :user
end

# == Schema Information
#
# Table name: user_passwords
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  hash       :string(64)       not null
#  salt       :string(32)       not null
#  algorithm  :string(64)       not null
#  expired_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_user_passwords_on_user_id                          (user_id) UNIQUE WHERE (expired_at IS NULL)
#  index_user_passwords_on_user_id_and_expired_at_and_hash  (user_id,expired_at,hash)
#
