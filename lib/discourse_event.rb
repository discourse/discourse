# frozen_string_literal: true

# This is meant to be used by plugins to trigger and listen to events
# So we can execute code when things happen.
class DiscourseEvent

  # Defaults to a hash where default values are empty sets.
  def self.events
    @events ||= Hash.new { |hash, key| hash[key] = Set.new }
  end

  def self.trigger(event_name, *params)
    events[event_name].each do |event|
      event.call(*params)
    end
  end

  def self.on(event_name, &block)
    if event_name == :site_setting_saved
      Discourse.deprecate("The :site_setting_saved event is deprecated. Please use :site_setting_changed instead", since: "2.3.0beta8", drop_from: "2.4", raise_error: true)
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
