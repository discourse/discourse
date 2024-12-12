# frozen_string_literal: true

# see https://samsaffron.com/archive/2017/10/18/fastest-way-to-profile-a-method-in-ruby
class MethodProfiler
  def self.patch(klass, methods, name, no_recurse: false)
    patches =
      methods
        .map do |method_name|
          recurse_protection = ""
          recurse_protection = <<~RUBY if no_recurse
          return #{method_name}__mp_unpatched(*args, &blk) if @mp_recurse_protect_#{method_name}
          @mp_recurse_protect_#{method_name} = true
        RUBY

          <<~RUBY
      unless defined?(#{method_name}__mp_unpatched)
        alias_method :#{method_name}__mp_unpatched, :#{method_name}
        def #{method_name}(*args, &blk)
          unless prof = Thread.current[:_method_profiler]
            return #{method_name}__mp_unpatched(*args, &blk)
          end
          #{recurse_protection}
          begin
            start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            #{method_name}__mp_unpatched(*args, &blk)
          ensure
            data = (prof[:#{name}] ||= {duration: 0.0, calls: 0})
            data[:duration] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
            data[:calls] += 1
            #{"@mp_recurse_protect_#{method_name} = false" if no_recurse}
          end
        end
      end
      RUBY
        end
        .join("\n")

    klass.class_eval patches
  end

  def self.patch_with_debug_sql(klass, methods, name, no_recurse: false)
    patches =
      methods
        .map do |method_name|
          recurse_protection = ""
          recurse_protection = <<~RUBY if no_recurse
          return #{method_name}__mp_unpatched_debug_sql(*args, &blk) if @mp_recurse_protect_#{method_name}
          @mp_recurse_protect_#{method_name} = true
        RUBY

          <<~RUBY
      unless defined?(#{method_name}__mp_unpatched_debug_sql)
        alias_method :#{method_name}__mp_unpatched_debug_sql, :#{method_name}
        def #{method_name}(*args, &blk)
          #{recurse_protection}

          query = args[0]
          should_filter = #{@@instrumentation_debug_sql_filter_transactions} &&
                            (query == "COMMIT" || query == "BEGIN" || query == "ROLLBACK")
          if !should_filter
            STDERR.puts "debugsql (sql): " + query
          end

          begin
            start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            #{method_name}__mp_unpatched_debug_sql(*args, &blk)
          ensure
            duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

            if !should_filter
              STDERR.puts "debugsql (sec): " + duration.round(3).to_s
            end

            #{"@mp_recurse_protect_#{method_name} = false" if no_recurse}
          end
        end
      end
      RUBY
        end
        .join("\n")

    klass.class_eval patches
  end

  def self.transfer
    result = Thread.current[:_method_profiler]
    Thread.current[:_method_profiler] = nil
    result
  end

  def self.start(transfer = nil)
    Thread.current[:_method_profiler] = transfer ||
      {
        __start: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        __start_gc_heap_live_slots: GC.stat[:heap_live_slots],
      }
  end

  def self.clear
    Thread.current[:_method_profiler] = nil
  end

  def self.stop
    finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    if data = Thread.current[:_method_profiler]
      Thread.current[:_method_profiler] = nil
      start = data.delete(:__start)
      data[:total_duration] = finish - start
    end

    data
  end

  ##
  # This is almost the same as ensure_discourse_instrumentation! but should not
  # be used in production. This logs all SQL queries run and their durations
  # between start and stop.
  #
  # filter_transactions - When true, we do not record timings of transaction
  # related commits (BEGIN, COMMIT, ROLLBACK)
  def self.output_sql_to_stderr!(filter_transactions: false)
    Rails.logger.warn(
      "Stop! This instrumentation is not intended for use in production outside of debugging scenarios. Please be sure you know what you are doing when enabling this instrumentation.",
    )
    @@instrumentation_debug_sql_filter_transactions = filter_transactions
    @@instrumentation_setup_debug_sql ||=
      begin
        MethodProfiler.patch_with_debug_sql(
          PG::Connection,
          %i[exec async_exec exec_prepared send_query_prepared query exec_params],
          :sql,
        )
        true
      end
  end

  def self.ensure_discourse_instrumentation!
    @@instrumentation_setup ||=
      begin
        MethodProfiler.patch(
          PG::Connection,
          %i[exec async_exec exec_prepared send_query_prepared query exec_params],
          :sql,
        )

        MethodProfiler.patch(Redis::Client, %i[call call_pipeline], :redis)

        MethodProfiler.patch(Net::HTTP, [:request], :net, no_recurse: true)

        MethodProfiler.patch(Excon::Connection, [:request], :net)
        true
      end
  end
end
