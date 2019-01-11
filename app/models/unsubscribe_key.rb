class UnsubscribeKey < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
  belongs_to :topic

  before_create :generate_random_key

  def self.create_key_for(user, type)
    if Post === type
      create(user_id: user.id, unsubscribe_key_type: "topic", topic_id: type.topic_id, post_id: type.id).key
    else
      create(user_id: user.id, unsubscribe_key_type: type).key
    end
  end

  def self.user_for_key(key)
    where(key: key).first.try(:user)
  end

  private

  def generate_random_key
    self.key = SecureRandom.hex(32)
  end
end

# == Schema Information
#
# Table name: unsubscribe_keys
#
#  key                  :string(64)       not null, primary key
#  user_id              :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  unsubscribe_key_type :string
#  topic_id             :integer
#  post_id              :integer
#
# Indexes
#
#  index_unsubscribe_keys_on_created_at  (created_at)
#
