# This is meant to be used by plugins to trigger and listen to events
# So we can execute code when things happen.
module DiscourseEvent

  class << self

    def trigger(event_name, *params)

      return unless @events      
      return unless event_list = @events[event_name]

      event_list.each do |ev|
        ev.call(*params)
      end
    end

    def on(event_name, &block)
      @events ||= {}
      @events[event_name] ||= Set.new
      @events[event_name] << block
    end

    def clear
      @events = {}
    end
  end

end
