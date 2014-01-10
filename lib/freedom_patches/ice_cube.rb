module IceCube
  class MinutelyRule < ValidatedRule
    def initialize(interval = 1, week_start = :sunday)
      super

      unless interval == 1
        raise "Due to a gigantic awful bug in ice_cube, don't specify an interval for minutely. Use `hourly.minute_of_hour`"
      end

      interval(interval)
      schedule_lock(:sec)
      reset
    end
  end
end

