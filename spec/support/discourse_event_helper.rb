# frozen_string_literal: true

module DiscourseEvent::TestHelper
  def trigger(event_name, *params)
    super(event_name, *params)

    if @events_trigger
      @events_trigger << { event_name: event_name, params: params }
    end
  end

  def track_events
    @events_trigger = events_trigger = []
    yield
    @events_trigger = nil
    events_trigger
  end

  def track(event_type)
    events = track_events { yield }
    events.find { |e| e[:event_name] == event_type }
  end

end

DiscourseEvent.singleton_class.prepend DiscourseEvent::TestHelper
