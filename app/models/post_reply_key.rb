class PostReplyKey < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  before_validation { self.reply_key ||= self.class.generate_reply_key }

  validates :post_id, presence: true, uniqueness: { scope: :user_id }
  validates :user_id, presence: true
  validates :reply_key, presence: true

  def reply_key
    super&.delete('-')
  end

  def self.generate_reply_key
    SecureRandom.hex(16)
  end
end

# == Schema Information
#
# Table name: post_reply_keys
#
#  id         :bigint(8)        not null, primary key
#  user_id    :integer          not null
#  post_id    :integer          not null
#  reply_key  :uuid             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_post_reply_keys_on_reply_key            (reply_key) UNIQUE
#  index_post_reply_keys_on_user_id_and_post_id  (user_id,post_id) UNIQUE
#
