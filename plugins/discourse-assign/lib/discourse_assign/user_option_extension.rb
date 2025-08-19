# frozen_string_literal: true

module DiscourseAssign
  module UserOptionExtension
    extend ActiveSupport::Concern

    prepended do
      enum :notification_level_when_assigned,
           { do_nothing: 1, track_topic: 2, watch_topic: 3 },
           suffix: "when_assigned"
    end
  end
end
