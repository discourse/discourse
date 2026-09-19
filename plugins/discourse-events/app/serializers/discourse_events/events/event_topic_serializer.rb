# frozen_string_literal: true

module DiscourseEvents
  module Events
    class EventTopicSerializer < ApplicationSerializer
      include TopicTagsMixin

      attributes :id
      attributes :title
      attributes :slug
    end
  end
end
