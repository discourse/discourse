# frozen_string_literal: true

class DiscourseSolved::ToggleMeToo
  include Service::Base

  params do
    attribute :topic_id, :integer

    validates :topic_id, presence: true
  end

  model :topic
  policy :can_me_too
  model :existing_me_too, optional: true

  lock(:topic) do
    transaction do
      only_if(:existing_me_too_present?) { step :withdraw_me_too }
      only_if(:existing_me_too_absent?) do
        model :me_too, :record_me_too
        only_if(:notification_level_below_tracking?) { step :start_tracking_topic }
      end
    end
  end

  step :publish_me_too_change

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def can_me_too(guardian:, topic:)
    guardian.can_me_too?(topic)
  end

  def fetch_existing_me_too(topic:, guardian:)
    DiscourseSolved::TopicMeToo.find_by(topic_id: topic.id, user_id: guardian.user.id)
  end

  def existing_me_too_present?(existing_me_too:)
    existing_me_too.present?
  end

  def existing_me_too_absent?(existing_me_too:)
    existing_me_too.blank?
  end

  def withdraw_me_too(existing_me_too:)
    existing_me_too.destroy!
  end

  def record_me_too(topic:, guardian:)
    DiscourseSolved::TopicMeToo.create(topic:, user: guardian.user)
  end

  def notification_level_below_tracking?(topic:, guardian:)
    current_level =
      TopicUser.get(topic, guardian.user)&.notification_level ||
        TopicUser.notification_levels[:regular]
    current_level < TopicUser.notification_levels[:tracking]
  end

  def start_tracking_topic(topic:, guardian:)
    TopicUser.change(
      guardian.user.id,
      topic.id,
      notification_level: TopicUser.notification_levels[:tracking],
    )
  end

  def publish_me_too_change(topic:, existing_me_too:)
    MessageBus.publish(
      "/topic/#{topic.id}",
      { type: :me_too, count: topic.me_too_count, user_did_me_too: existing_me_too.blank? },
      topic.secure_audience_publish_messages,
    )
  end
end
