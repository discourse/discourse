# frozen_string_literal: true

class NestedTopic::TogglePin
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :post_id, :integer

    validates :topic_id, presence: true
    validates :post_id, presence: true
  end

  model :topic
  model :post
  policy :staff_can_edit
  policy :post_is_root
  model :nested_topic, :find_or_create_nested_topic
  policy :within_pin_limit
  transaction { step :toggle_pin }

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def fetch_post(topic:, params:)
    topic.posts.find_by(id: params.post_id)
  end

  def staff_can_edit(guardian:, topic:)
    guardian.can_edit?(topic) && guardian.is_staff?
  end

  def post_is_root(post:)
    post.reply_to_post_number.blank? || post.reply_to_post_number == 1
  end

  def find_or_create_nested_topic(topic:)
    topic.nested_topic || NestedTopic.find_or_create_by!(topic: topic)
  end

  def within_pin_limit(nested_topic:, post:)
    !nested_topic.pin_limit_reached? || nested_topic.pinned_post_ids.include?(post.id)
  end

  def toggle_pin(nested_topic:, post:)
    nested_topic.toggle_pin(post.id)
  end
end
