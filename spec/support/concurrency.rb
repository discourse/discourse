# frozen_string_literal: true

require 'fiber'

module Concurrency
  module Logic
    class DeadEnd < StandardError; end

    module Complete
      class Path
        def initialize
          @path = []
          @index = 0
        end

        def to_s
          "#<Logic::Complete::Path path=#{@path}>"
        end

        def choose(*options)
          raise DeadEnd if options.empty?

          @path << [options.size, 0] unless @index < @path.size

          pair = @path[@index]
          raise "non-determinism" unless pair[0] == options.size

          @index += 1
          options[pair[1]]
        end

        def choose_with_weights(*options)
          choose(*options.map(&:first))
        end

        def dead_end
          raise DeadEnd
        end

        def guard(condition)
          dead_end unless condition
        end

        def next
          @index = 0

          until @path.empty?
            pair = @path.last
            pair[1] += 1
            if pair[1] < pair[0]
              break
            else
              @path.pop
            end
          end

          !@path.empty?
        end
      end

      def self.run(&blk)
        path = Path.new
        possibilities = []

        while true
          begin
            possibilities << blk.call(path)
          rescue DeadEnd
          end

          break unless path.next
        end

        possibilities
      end
    end

    module Sampling
      class Path
        def initialize(random)
          @random = random
        end

        def to_s
          "#<Logic::Sampling::Path seed=#{@random.seed}>"
        end

        def choose(*options)
          options.sample(random: @random)
        end

        def choose_with_weights(*options)
          position = @random.rand
          options.each do |(option, weight)|
            if position <= weight
              return option
            else
              position -= weight
            end
          end
          raise "weights don't add up"
        end

        def dead_end
          raise DeadEnd
        end

        def guard(condition)
          dead_end unless condition
        end
      end

      def self.run(seed, runs, &blk)
        seed = seed.to_i
        possibilities = []

        runs.times do |i|
          path = Path.new(Random.new(seed + i))

          begin
            possibilities << blk.call(path)
          rescue DeadEnd
          end
        end

        possibilities
      end
    end

    def self.run(seed: nil, runs: nil, &blk)
      if runs.present?
        Sampling.run(seed, runs, &blk)
      else
        Complete.run(&blk)
      end
    end
  end

  class Scenario
    def initialize(&blk)
      @blk = blk
    end

    class Execution
      attr_reader :path

      def initialize(path)
        @path = path
        @tasks = []
        @time = 0
      end

      def yield
        sleep(0)
      end

      def choose(*options)
        @path.choose(*options)
      end

      def choose_with_weights(*options)
        @path.choose_with_weights(*options)
      end

      def stop_other_tasks
        @tasts = @tasks.select! { |task| task[:fiber] == Fiber.current }
      end

      def sleep(length)
        Fiber.yield(@time + length)
      end

      def start_root(&blk)
        descriptor = {
          fiber: Fiber.new(&blk),
          run_at: 0
        }

        @tasks << descriptor
      end

      def spawn(&blk)
        descriptor = {
          fiber: Fiber.new(&blk),
          run_at: @time
        }

        @tasks << descriptor

        self.yield
      end

      def run(sleep_order: false)
        until @tasks.empty?
          descriptor =
            if sleep_order
              @tasks.sort_by! { |x| x[:run_at] }
              run_at = @tasks.first[:run_at]
              @path.choose(*@tasks.take_while { |x| x[:run_at] == run_at })
            else
              @path.choose(*@tasks)
            end

          @time = [@time, descriptor[:run_at]].max
          fiber = descriptor[:fiber]

          begin
            run_at = fiber.resume
          rescue Exception
          end

          if fiber.alive?
            descriptor[:run_at] = run_at
          else
            @tasks.delete(descriptor)
          end
        end
      end

      def wait_done
        until @tasks.size == 1
          self.sleep(1e9)
        end
      end

      def new_mutex
        Mutex.new(self)
      end
    end

    def run_with_path(path, sleep_order: false)
      execution = Execution.new(path)
      result = {}
      execution.start_root {
        result[:value] = @blk.call(execution)
      }
      execution.run(sleep_order: sleep_order)
      result
    end

    def run(sleep_order: false, **opts)
      Logic.run(**opts) do |path|
        run_with_path(path, sleep_order: sleep_order)
      end
    end
  end

  class RedisWrapper
    def initialize(redis, execution)
      @redis = redis
      @execution = execution
      @in_transaction = false
    end

    def multi(&blk)
      with_possible_failure do
        with_in_transaction do
          @redis.multi(&blk)
        end
      end
    end

    def method_missing(method, *args, &blk)
      if @in_transaction
        @redis.send(method, *args, &blk)
      else
        with_possible_failure do
          @redis.send(method, *args, &blk)
        end
      end
    end

    private

    def with_in_transaction
      previous_value, @in_transaction = @in_transaction, true

      begin
        yield
      ensure
        @in_transaction = previous_value
      end
    end

    def with_possible_failure
      outcome =
        @execution.choose_with_weights(
          [:succeed, 0.96],
          [:fail_before, 0.02],
          [:fail_after, 0.02]
        )

      @execution.yield

      if outcome == :fail_before
        raise Redis::ConnectionError
      end

      result = yield

      @execution.yield

      if outcome == :fail_after
        raise Redis::ConnectionError
      end

      result
    end
  end

  class Mutex
    def initialize(execution)
      @execution = execution
      @locked_by = nil
    end

    def lock
      @execution.yield

      fiber = Fiber.current
      while true
        if @locked_by.nil?
          @locked_by = fiber
          return
        elsif @locked_by == fiber
          raise ThreadError, "deadlock; recursive locking"
        else
          @execution.yield
        end
      end
    end

    def unlock
      @execution.yield

      if @locked_by != Fiber.current
        raise ThreadError, "Attempt to unlock a mutex which is locked by another thread"
      end
      @locked_by = nil
    end

    def synchronize
      lock
      begin
        yield
      ensure
        unlock
      end
    end
  end
end
