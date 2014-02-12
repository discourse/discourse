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

      key = Manager.schedule_key(klass)
      data = nil

      if data = $redis.get(key)
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

    def valid?
      return false unless @next_run
      (!@prev_run && @next_run < Time.now.to_i + 5.minutes) ||
      ( @prev_run &&
        @prev_run <= Time.now.to_i &&
        @next_run < @prev_run + @klass.every * (1 + @manager.random_ratio)
      )
    end

    def schedule!
      if !valid? && @prev_run
        mixup = @klass.every * @manager.random_ratio
        mixup = (mixup * Random.rand - mixup / 2).to_i
        @next_run = @prev_run + mixup + @klass.every
      end

      if !valid?
        @next_run = Time.now.to_i + 5.minutes * Random.rand
      end

      write!
    end

    def write!
      key = Manager.schedule_key(@klass)
      clear!
      redis.set key, {
        next_run: @next_run,
        prev_run: @prev_run,
        prev_duration: @prev_duration,
        prev_result: @prev_result,
        current_owner: @current_owner
      }.to_json
      redis.zadd Manager.queue_key, @next_run , @klass
    end

    def del!
      clear!
      @next_run = @prev_run = @prev_result = @prev_duration = @current_owner = nil
    end

    def key
      Manager.schedule_key(@klass)
    end

    def redis
      @manager.redis
    end

    private
    def clear!
      key = Manager.schedule_key(@klass)
      redis.del key
      redis.zrem Manager.queue_key, key
    end

  end
end
