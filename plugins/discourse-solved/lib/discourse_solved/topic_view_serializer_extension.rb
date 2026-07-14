# frozen_string_literal: true

module DiscourseSolved::TopicViewSerializerExtension
  extend ActiveSupport::Concern

  prepended { attributes :accepted_answers, :has_accepted_answer }

  def include_accepted_answers?
    SiteSetting.solved_enabled? && object.topic.topic_answers.any?
  end

  def accepted_answers
    DiscourseSolved::AcceptedAnswersHelper.serialize(object.topic, scope)
  end

  def include_has_accepted_answer?
    SiteSetting.solved_enabled?
  end

  def has_accepted_answer
    object.topic.topic_answers.any?
  end
end
