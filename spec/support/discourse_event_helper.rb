# frozen_string_literal: true

module DiscourseEvent::TestHelper
  def trigger(event_name, *params, **kwargs)
    super(event_name, *params, **kwargs)

    if @events_trigger
      params << kwargs if kwargs != {}
      @events_trigger << { event_name: event_name, params: params }
    end
  end

  def track_events(event_name = nil, args: nil)
    @events_trigger = events_trigger = []
    yield events_trigger
    @events_trigger = nil

    if event_name
      events_trigger =
        events_trigger.filter do |event|
          next if event[:event_name] != event_name
          next if args && event[:params] != args
          true
        end
    end

    events_trigger
  end

  def track(event_name, args: nil)
    events = track_events(event_name, args: args) { yield }
    events.first
  end
end

DiscourseEvent.singleton_class.prepend DiscourseEvent::TestHelper

# Fail any spec that registers a DiscourseEvent handler without cleaning it up.
RSpec.configure do |config|
  config.around :each do |example|
    before_event_count = DiscourseEvent.events.values.sum(&:count)
    example.run
    after_event_count = DiscourseEvent.events.values.sum(&:count)
    expect(before_event_count).to eq(after_event_count),
    "DiscourseEvent registrations were not cleaned up"
  end
end
