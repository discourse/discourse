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
    events[event_name] << block
  end

  def self.off(event_name, &block)
    events[event_name].delete(block)
  end

end
