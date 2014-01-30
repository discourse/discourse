module Scheduler::Schedule
  def every(duration=nil)
    @every ||= duration
  end
end
