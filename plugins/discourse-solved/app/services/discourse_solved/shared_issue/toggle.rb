# frozen_string_literal: true

class DiscourseSolved::SharedIssue::Toggle
  include Service::Base

  params do
    attribute :topic_id, :integer

    validates :topic_id, presence: true
  end

  model :topic
  policy :can_create_shared_issue

  lock(:topic) do
    model :existing_shared_issue, optional: true

    transaction do
      only_if(:existing_shared_issue_present?) { step :withdraw_shared_issue }
      only_if(:existing_shared_issue_absent?) do
        model :shared_issue, :create_shared_issue
        only_if(:notification_level_below_tracking?) { step :start_tracking_topic }
      end
    end
  end

  step :publish_shared_issue_change

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def can_create_shared_issue(guardian:, topic:)
    guardian.can_create_shared_issue?(topic)
  end

  def fetch_existing_shared_issue(topic:, guardian:)
    DiscourseSolved::SharedIssue.find_by(topic:, user: guardian.user)
  end

  def existing_shared_issue_present?(existing_shared_issue:)
    existing_shared_issue.present?
  end

  def existing_shared_issue_absent?(existing_shared_issue:)
    existing_shared_issue.blank?
  end

  def withdraw_shared_issue(existing_shared_issue:)
    existing_shared_issue.destroy
  end

  def create_shared_issue(topic:, guardian:)
    DiscourseSolved::SharedIssue.create(topic:, user: guardian.user)
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

  def publish_shared_issue_change(topic:, existing_shared_issue:)
    MessageBus.publish(
      "/topic/#{topic.id}",
      {
        type: :shared_issue,
        count: DiscourseSolved::SharedIssue.count_for(topic),
        user_created_shared_issue: existing_shared_issue.blank?,
      },
      topic.secure_audience_publish_messages,
    )
  end
end
