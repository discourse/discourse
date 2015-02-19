class DigestUnsubscribeKey < ActiveRecord::Base
  belongs_to :user

  before_create :generate_random_key

  def self.create_key_for(user)
    DigestUnsubscribeKey.create(user_id: user.id).key
  end

  def self.user_for_key(key)
    where(key: key).first.try(:user)
  end

  private

    def generate_random_key
      self.key = SecureRandom.hex(32)
    end
end
