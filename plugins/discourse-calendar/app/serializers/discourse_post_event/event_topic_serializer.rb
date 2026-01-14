# frozen_string_literal: true

module DiscoursePostEvent
  class EventTopicSerializer < ApplicationSerializer
    include TopicTagsMixin

    attributes :id
    attributes :title
  end
end
