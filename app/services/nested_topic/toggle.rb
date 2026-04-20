# frozen_string_literal: true

class NestedTopic::Toggle
  include Service::Base

  params do
    attribute :topic_id, :integer
    attribute :enabled, :boolean

    validates :topic_id, presence: true
    validates :enabled, inclusion: { in: [true, false] }
  end

  model :topic
  policy :staff_can_edit

  transaction do
    only_if(:enabling) { step :enable_nested_view }
    only_if(:disabling) { step :disable_nested_view }
  end

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def staff_can_edit(guardian:, topic:)
    guardian.can_edit?(topic) && guardian.is_staff?
  end

  def enabling(params:)
    params.enabled
  end

  def disabling(params:)
    !params.enabled
  end

  def enable_nested_view(topic:)
    NestedTopic.find_or_create_by!(topic: topic) unless topic.nested_topic
  end

  def disable_nested_view(topic:)
    topic.nested_topic&.destroy!
  end
end
