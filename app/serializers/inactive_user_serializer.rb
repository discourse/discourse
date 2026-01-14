# frozen_string_literal: true

class InactiveUserSerializer < BasicUserSerializer
  attr_accessor :topic_post_count

  attributes :inactive, :topic_post_count

  def inactive
    !object.active?
  end

  def include_topic_post_count?
    topic_post_count.present?
  end
end
