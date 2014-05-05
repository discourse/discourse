# Initially we used sidetiq, this was a problem:
#
# 1. No mechnism to add "randomisation" into job execution
# 2. No stats about previous runs or failures
# 3. Dependency on ice_cube gem causes runaway CPU

require_dependency 'distributed_mutex'

module Scheduler
  class Manager
    attr_accessor :random_ratio, :redis


    class Runner
      def initialize(manager)
        @mutex = Mutex.new
        @queue = Queue.new
        @manager = manager
        @reschedule_orphans_thread = Thread.new do
          while true
            sleep 1.minute
            @mutex.synchronize do
              reschedule_orphans
            end
          end
        end
        @keep_alive_thread = Thread.new do
          while true
            @mutex.synchronize do
              keep_alive
            end
            sleep (@manager.keep_alive_duration / 2)
          end
        end
        @thread = Thread.new do
          while true
            process_queue
          end
        end
      end

      def keep_alive
        @manager.keep_alive
      rescue => ex
        Discourse.handle_exception(ex)
      end

      def reschedule_orphans
        @manager.reschedule_orphans!
      rescue => ex
        Discourse.handle_exception(ex)
      end

      def process_queue
        klass = @queue.deq
        # hack alert, I need to both deq and set @running atomically.
        @running = true
        failed = false
        start = Time.now.to_f
        info = @mutex.synchronize { @manager.schedule_info(klass) }
        begin
          info.prev_result = "RUNNING"
          @mutex.synchronize { info.write! }
          klass.new.perform
        rescue => e
          Discourse.handle_exception(e)
          failed = true
        end
        duration = ((Time.now.to_f - start) * 1000).to_i
        info.prev_duration = duration
        info.prev_result = failed ? "FAILED" : "OK"
        info.current_owner = nil
        attempts(3) do
          @mutex.synchronize { info.write! }
        end
      rescue => ex
        Discourse.handle_exception(ex)
      ensure
        @running = false
      end

      def stop!
        @mutex.synchronize do
          @thread.kill
          @keep_alive_thread.kill
          @reschedule_orphans_thread.kill
        end
      end

      def enq(klass)
        @queue << klass
      end

      def wait_till_done
        while !@queue.empty? && !(@queue.num_waiting > 0)
          sleep 0.001
        end
        # this is a hack, but is only used for test anyway
        sleep 0.001
        while @running
          sleep 0.001
        end
      end

      def attempts(n)
        n.times {
          begin
            yield; break
          rescue
            sleep Random.rand
          end
        }
      end

    end

    def self.without_runner(redis=nil)
      self.new(redis, true)
    end

    def initialize(redis = nil, skip_runner = false)
      @redis = $redis || redis
      @random_ratio = 0.1
      unless skip_runner
        @runner = Runner.new(self)
        self.class.current = self
      end
      @manager_id = SecureRandom.hex
    end

    def self.current
      @current
    end

    def self.current=(manager)
      @current = manager
    end

    def schedule_info(klass)
      ScheduleInfo.new(klass, self)
    end

    def next_run(klass)
      schedule_info(klass).next_run
    end

    def ensure_schedule!(klass)
      lock do
        schedule_info(klass).schedule!
      end

    end

    def remove(klass)
      lock do
        schedule_info(klass).del!
      end
    end

    def reschedule_orphans!
      lock do
        redis.zrange(Manager.queue_key, 0, -1).each do |key|
          klass = get_klass(key)
          next unless klass
          info = schedule_info(klass)

          if ['QUEUED', 'RUNNING'].include?(info.prev_result) &&
            (info.current_owner.blank? || !redis.get(info.current_owner))
            info.prev_result = 'ORPHAN'
            info.next_run = Time.now.to_i
            info.write!
          end
        end
      end
    end

    def get_klass(name)
      name.constantize
    rescue NameError
      nil
    end

    def tick
      lock do
        (key, due), _ = redis.zrange Manager.queue_key, 0, 0, withscores: true
        return unless key
        if due.to_i <= Time.now.to_i
          klass = get_klass(key)
          unless klass
            # corrupt key, nuke it (renamed job or something)
            redis.zrem Manager.queue_key, key
            return
          end
          info = schedule_info(klass)
          info.prev_run = Time.now.to_i
          info.prev_result = "QUEUED"
          info.prev_duration = -1
          info.next_run = nil
          info.current_owner = identity_key
          info.schedule!
          @runner.enq(klass)
        end
      end
    end

    def blocking_tick
      tick
      @runner.wait_till_done
    end

    def stop!
      @runner.stop!
      self.class.current = nil
    end

    def keep_alive_duration
      60
    end

    def keep_alive
      redis.setex identity_key, keep_alive_duration, ""
    end

    def lock
      DistributedMutex.new(Manager.lock_key).synchronize do
        yield
      end
    end


    def self.discover_schedules
      # hack for developemnt reloader is crazytown
      # multiple classes with same name can be in
      # object space
      unique = Set.new
      schedules = []
      ObjectSpace.each_object(Scheduler::Schedule) do |schedule|
        if schedule.scheduled?
          next if unique.include?(schedule.to_s)
          schedules << schedule
          unique << schedule.to_s
        end
      end
      schedules
    end

    @mutex = Mutex.new
    def self.seq
      @mutex.synchronize do
        @i ||= 0
        @i += 1
      end
    end

    def identity_key
      @identity_key ||= "_scheduler_#{`hostname`}:#{Process.pid}:#{self.class.seq}"
    end

    def self.lock_key
      "_scheduler_lock_"
    end

    def self.queue_key
      "_scheduler_queue_"
    end

    def self.schedule_key(klass)
      "_scheduler_#{klass}"
    end
  end
end
