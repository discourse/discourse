# frozen_string_literal: true

module DiscourseSolved::TopicViewSerializerExtension
  extend ActiveSupport::Concern

  prepended { attributes :accepted_answers }

  def include_accepted_answers?
    SiteSetting.solved_enabled? && object.topic.solved&.topic_answers&.any?
  end

  def accepted_answers
    DiscourseSolved::AcceptedAnswersSerializer.serialize(object.topic, scope)
  end
end
