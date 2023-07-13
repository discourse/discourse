# frozen_string_literal: true

# This is meant to be used by plugins to trigger and listen to events
# So we can execute code when things happen.
class DiscourseEvent
  # Defaults to a hash where default values are empty sets.
  def self.events
    @events ||= Hash.new { |hash, key| hash[key] = Set.new }
  end

  def self.trigger(event_name, *args, **kwargs)
    events[event_name].each { |event| event.call(*args, **kwargs) }
  end

  def self.on(event_name, &block)
    if event_name == :site_setting_saved
      Discourse.deprecate(
        "The :site_setting_saved event is deprecated. Please use :site_setting_changed instead",
        since: "2.3.0beta8",
        drop_from: "2.4",
        raise_error: true,
      )
    end

    if event_name == :user_badge_removed
      Discourse.deprecate(
        "The :user_badge_removed event is deprecated. Please use :user_badge_revoked instead",
        since: "3.1.0.beta5",
        drop_from: "3.2.0.beta1",
        output_in_test: true,
      )
    end

    events[event_name] << block
  end

  def self.off(event_name, &block)
    raise ArgumentError.new "DiscourseEvent.off must reference a block" if block.nil?
    events[event_name].delete(block)
  end

  def self.all_off(event_name)
    events.delete(event_name)
  end
end
