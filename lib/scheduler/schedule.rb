module Scheduler::Schedule

  def daily(options=nil)
    if options
      @daily = options
    end
    @daily
  end

  def every(duration=nil)
    if duration
      @every = duration
      if manager = Scheduler::Manager.current
        manager.ensure_schedule!(self)
      end
    end
    @every
  end

  def schedule_info
    manager = Scheduler::Manager.without_runner
    manager.schedule_info self
  end

  def scheduled?
    !!@every || !!@daily
  end
end
