# frozen_string_literal: true

class UnsubscribeKey < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
  belongs_to :topic

  before_create :generate_random_key

  ALL_TYPE = "all"
  DIGEST_TYPE = "digest"
  TOPIC_TYPE = "topic"

  class << self
    def create_key_for(user, type, post: nil)
      unsubscribe_key = new(user_id: user.id, unsubscribe_key_type: type)

      if type == TOPIC_TYPE
        unsubscribe_key.topic_id = post.topic_id
        unsubscribe_key.post_id = post.id
      end

      unsubscribe_key.save!
      unsubscribe_key.key
    end

    def user_for_key(key)
      where(key: key).first&.user
    end

    def get_unsubscribe_strategy_for(key)
      strategies = {
        DIGEST_TYPE => EmailControllerHelper::DigestEmailUnsubscriber,
        TOPIC_TYPE => EmailControllerHelper::TopicEmailUnsubscriber,
        ALL_TYPE => EmailControllerHelper::BaseEmailUnsubscriber,
      }

      DiscoursePluginRegistry.email_unsubscribers.each do |unsubcriber|
        strategies.merge!(unsubcriber)
      end

      strategies[key.unsubscribe_key_type]&.new(key)
    end
  end

  def associated_topic
    @associated_topic ||= topic || post&.topic
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
