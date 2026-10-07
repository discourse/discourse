# frozen_string_literal: true

module DiscourseEvents
  module Events
    class EventHostSerializer < BasicUserSerializer
      attributes :title
    end
  end
end
