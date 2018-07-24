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
