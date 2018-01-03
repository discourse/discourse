module Scheduler
  class ScheduleInfo
    attr_accessor :next_run,
                  :prev_run,
                  :prev_duration,
                  :prev_result,
                  :current_owner

    def initialize(klass, manager)
      @klass = klass
      @manager = manager

      data = nil

      if data = @manager.redis.get(key)
        data = JSON.parse(data)
      end

      if data
        @next_run = data["next_run"]
        @prev_run = data["prev_run"]
        @prev_result = data["prev_result"]
        @prev_duration = data["prev_duration"]
        @current_owner = data["current_owner"]
      end
    rescue
      # corrupt redis
      @next_run = @prev_run = @prev_result = @prev_duration = @current_owner = nil
    end

    # this means the schedule is going to fire, it is setup correctly
    # invalid schedules are fixed by running "schedule!"
    # this happens automatically after if fire by the manager
    def valid?
      return false unless @next_run
      (!@prev_run && @next_run < Time.now.to_i + 5.minutes) || valid_every? || valid_daily?
    end

    def valid_every?
      return false unless @klass.every
      !!@prev_run &&
        @prev_run <= Time.now.to_i &&
        @next_run < @prev_run + @klass.every * (1 + @manager.random_ratio)
    end

    def valid_daily?
      return false unless @klass.daily
      return true if !@prev_run && @next_run && @next_run <= (Time.zone.now + 1.day).to_i
      !!@prev_run &&
        @prev_run <= Time.zone.now.to_i &&
        @next_run < @prev_run + 1.day
    end

    def schedule_every!
      if !valid? && @prev_run
        mixup = @klass.every * @manager.random_ratio
        mixup = (mixup * Random.rand - mixup / 2).to_i
        @next_run = @prev_run + mixup + @klass.every
      end

      if !valid?
        @next_run = Time.now.to_i + 5.minutes * Random.rand
      end
    end

    def schedule_daily!
      return if valid?

      at = @klass.daily[:at] || 0
      today_begin = Time.zone.now.midnight.to_i
      today_offset = DateTime.now.seconds_since_midnight

      # If it's later today
      if at > today_offset
        @next_run = today_begin + at
      else
        # Otherwise do it tomorrow
        @next_run = today_begin + 1.day + at
      end
    end

    def schedule!
      if @klass.every
        schedule_every!
      elsif @klass.daily
        schedule_daily!
      end

      write!
    end

    def write!

      clear!
      redis.set key, {
        next_run: @next_run,
        prev_run: @prev_run,
        prev_duration: @prev_duration,
        prev_result: @prev_result,
        current_owner: @current_owner
      }.to_json

      redis.zadd queue_key, @next_run, @klass if @next_run
    end

    def del!
      clear!
      @next_run = @prev_run = @prev_result = @prev_duration = @current_owner = nil
    end

    def key
      if @klass.is_per_host
        Manager.schedule_key(@klass, @manager.hostname)
      else
        Manager.schedule_key(@klass)
      end
    end

    def queue_key
      if @klass.is_per_host
        Manager.queue_key(@manager.hostname)
      else
        Manager.queue_key
      end
    end

    def redis
      @manager.redis
    end

    private
    def clear!
      redis.del key
      redis.zrem queue_key, @klass
    end

  end
end
