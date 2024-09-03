# frozen_string_literal: true

class UserPassword < ActiveRecord::Base
  validates :user_id, presence: true

  validates :user_id, uniqueness: true
  validates :password_hash, presence: true, length: { is: 64 }, uniqueness: { scope: :user_id }
  validates :password_salt, presence: true, length: { is: 32 }
  validates :password_algorithm, presence: true, length: { maximum: 64 }

  belongs_to :user
end

# == Schema Information
#
# Table name: user_passwords
#
#  id                  :integer          not null, primary key
#  user_id             :integer          not null
#  password_hash       :string(64)       not null
#  password_salt       :string(32)       not null
#  password_algorithm  :string(64)       not null
#  password_expired_at :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_user_passwords_on_user_id  (user_id) UNIQUE
#
