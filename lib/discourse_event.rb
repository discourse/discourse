# frozen_string_literal: true

# This is meant to be used by plugins to trigger and listen to events
# So we can execute code when things happen.
class DiscourseEvent
  # Defaults to a hash where default values are empty sets.
  def self.events
    @events ||= Hash.new { |h, k| h[k] = Set.new }
  end

  def self.filtered_events
    @filtered_events ||= Hash.new { |h, k| h[k] = Set.new }
  end

  def self.trigger(event_name, *args, **kwargs)
    events[event_name].each { |event| event.call(*args, **kwargs) }
    lookup_args = []
    args.each do |arg|
      lookup_args << arg
      filtered_events[[event_name, lookup_args]].each { |event| event.call(*args, **kwargs) }
    end
  end

  def self.on(event_name, *args, &block)
    case event_name
    when :user_badge_removed
      Discourse.deprecate(
        "The :user_badge_removed event is deprecated. Please use :user_badge_revoked instead",
        since: "3.1.0.beta5",
        drop_from: "3.2.0.beta1",
        output_in_test: true,
      )
    when :post_notification_alert
      Discourse.deprecate(
        "The :post_notification_alert event is deprecated. Please use :push_notification instead",
        since: "3.2.0.beta1",
        drop_from: "3.3.0.beta1",
        output_in_test: true,
      )
    else
      # ignore
    end

    if args.present?
      filtered_events[[event_name, args]] << block
    else
      events[event_name] << block
    end
  end

  def self.off(event_name, &block)
    raise ArgumentError.new "DiscourseEvent.off must reference a block" if block.nil?
    events[event_name].delete(block)
    filtered_events.each { |k, v| v.delete(block) if k[0] == event_name }
  end

  def self.all_off(event_name)
    events.delete(event_name)
    filtered_events.delete_if { |k, v| k[0] == event_name }
  end
end
