# frozen_string_literal: true

module DiscourseEvent::TestHelper
  def trigger(event_name, *params, **kwargs)
    super(event_name, *params, **kwargs)

    if @events_trigger
      @events_trigger << { event_name: event_name, params: params, kwargs: kwargs }
    end
  end

  def track_events(event_name = nil, args: nil, kwargs: nil)
    @events_trigger = events_trigger = []
    yield
    @events_trigger = nil

    if event_name
      events_trigger = events_trigger.filter do |event|
        next if event[:event_name] != event_name
        next if args && event[:params] != args
        next if kwargs && event[:kwargs] != kwargs
        true
      end
    end

    events_trigger
  end

  def track(event_name, args: nil, kwargs: nil)
    events = track_events(event_name, args: args, kwargs: kwargs) { yield }
    events.first
  end
end

DiscourseEvent.singleton_class.prepend DiscourseEvent::TestHelper
