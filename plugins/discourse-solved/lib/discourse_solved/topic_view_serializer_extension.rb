# frozen_string_literal: true

module DiscourseSolved::TopicViewSerializerExtension
  extend ActiveSupport::Concern

  prepended { attributes :accepted_answer }

  def include_accepted_answer?
    SiteSetting.solved_enabled? && object.topic.solved.present? &&
      object.topic.solved.answer_post.present?
  end

  def accepted_answer
    object.topic.accepted_answer_post_info
  end
end
