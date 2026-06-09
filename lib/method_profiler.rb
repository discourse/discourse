# frozen_string_literal: true

# see https://samsaffron.com/archive/2017/10/18/fastest-way-to-profile-a-method-in-ruby
class MethodProfiler
  ITEMIZED_NAMES = %i[sql redis net].freeze
  private_constant :ITEMIZED_NAMES

  MAX_ITEM_LENGTH = 2000
  private_constant :MAX_ITEM_LENGTH

  @@itemize_enabled = false

  def self.itemize_enabled=(value)
    @@itemize_enabled = value
  end

  def self.patch(klass, methods, name, no_recurse: false)
    itemize = ITEMIZED_NAMES.include?(name)

    patches =
      methods
        .map do |method_name|
          recurse_protection = ""
          recurse_protection = <<~RUBY if no_recurse
          return #{method_name}__mp_unpatched(*args, **kwargs, &blk) if @mp_recurse_protect_#{method_name}
          @mp_recurse_protect_#{method_name} = true
        RUBY

          item_capture = ""
          item_capture = <<~RUBY if itemize
          if prof[:__itemize]
            begin
              if (__mp_item = MethodProfiler.send(:__#{name}_item, self, args))
                (data[:items] ||= []) << __mp_item.merge!(duration_ms: __mp_elapsed * 1000.0)
              end
            rescue => __mp_error
              (data[:items] ||= []) << MethodProfiler.send(:__item_error, __mp_error)
            end
          end
        RUBY

          <<~RUBY
      unless defined?(#{method_name}__mp_unpatched)
        alias_method :#{method_name}__mp_unpatched, :#{method_name}
        def #{method_name}(*args, **kwargs, &blk)
          unless prof = Thread.current[:_method_profiler]
            return #{method_name}__mp_unpatched(*args, **kwargs, &blk)
          end
          #{recurse_protection}
          begin
            __mp_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            #{method_name}__mp_unpatched(*args, **kwargs, &blk)
          ensure
            __mp_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - __mp_start
            data = (prof[:#{name}] ||= {duration: 0.0, calls: 0})
            data[:duration] += __mp_elapsed
            data[:calls] += 1
            #{item_capture}
            #{"@mp_recurse_protect_#{method_name} = false" if no_recurse}
          end
        end
      end
      RUBY
        end
        .join("\n")

    klass.class_eval patches
  end

  def self.utf8(value)
    value.to_s.dup.force_encoding(Encoding::UTF_8).scrub("?")
  end
  private_class_method :utf8

  def self.truncate(string)
    return string if string.length <= MAX_ITEM_LENGTH
    "#{string[0, MAX_ITEM_LENGTH]}…(truncated, #{string.bytesize} bytes)"
  end
  private_class_method :truncate

  def self.__item_error(error)
    { error: truncate(utf8("#{error.class}: #{error.message}")) }
  end
  private_class_method :__item_error

  def self.__sql_item(_receiver, args)
    { sql: truncate(utf8(args[0])) }
  end
  private_class_method :__sql_item

  def self.__redis_item(_receiver, args)
    command = args[0]
    return { command: truncate(utf8(command)) } unless command.is_a?(Array)
    commands = command.first.is_a?(Array) ? command : [command]
    { command: truncate(commands.map { |entry| __redis_command(entry) }.join("; ")) }
  end
  private_class_method :__redis_item

  def self.__redis_command(command)
    return utf8(command) unless command.is_a?(Array)
    [utf8(command.first).upcase, *Array(command[1..]).map { |arg| utf8(arg) }].join(" ").strip
  end
  private_class_method :__redis_command

  def self.__net_item(receiver, args)
    if defined?(Net::HTTP) && receiver.is_a?(Net::HTTP)
      request = args[0]
      url = __http_url(receiver.use_ssl?, receiver.address, receiver.port, request.path)
      { method: utf8(request.method), url: truncate(utf8(url)) }
    elsif defined?(Excon::Connection) && receiver.is_a?(Excon::Connection)
      params = args[0] || {}
      data = receiver.respond_to?(:data) ? receiver.data.to_h : {}
      url =
        __http_url(
          data[:scheme].to_s == "https",
          data[:host],
          data[:port],
          params[:path] || data[:path],
        )
      { method: utf8(params[:method] || data[:method]).upcase, url: truncate(utf8(url)) }
    else
      { method: "", url: "" }
    end
  end
  private_class_method :__net_item

  def self.__http_url(ssl, host, port, path)
    scheme = ssl ? "https" : "http"
    default_port = ssl ? 443 : 80
    authority = port.nil? || port == default_port ? host : "#{host}:#{port}"
    "#{scheme}://#{authority}#{path}"
  end
  private_class_method :__http_url

  def self.patch_with_debug_sql(klass, methods, name, no_recurse: false)
    patches =
      methods
        .map do |method_name|
          recurse_protection = ""
          recurse_protection = <<~RUBY if no_recurse
          return #{method_name}__mp_unpatched_debug_sql(*args, **kwargs, &blk) if @mp_recurse_protect_#{method_name}
          @mp_recurse_protect_#{method_name} = true
        RUBY

          <<~RUBY
      unless defined?(#{method_name}__mp_unpatched_debug_sql)
        alias_method :#{method_name}__mp_unpatched_debug_sql, :#{method_name}
        def #{method_name}(*args, **kwargs, &blk)
          #{recurse_protection}

          query = args[0]
          should_filter = #{@@instrumentation_debug_sql_filter_transactions} &&
                            (query == "COMMIT" || query == "BEGIN" || query == "ROLLBACK")
          if !should_filter
            STDERR.puts "debugsql (sql): " + query
          end

          begin
            start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            #{method_name}__mp_unpatched_debug_sql(*args, **kwargs, &blk)
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

  def self.start(transfer = nil, itemize: @@itemize_enabled)
    prof =
      transfer ||
        {
          __start: Process.clock_gettime(Process::CLOCK_MONOTONIC),
          __start_gc_heap_live_slots: GC.stat[:heap_live_slots],
        }
    if itemize
      prof[:__itemize] = true
    else
      prof.delete(:__itemize)
    end
    Thread.current[:_method_profiler] = prof
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

        MethodProfiler.patch(Redis::Client, %i[call_v], :redis)
        MethodProfiler.patch(RedisClient::RubyConnection, %i[call_pipelined], :redis)

        MethodProfiler.patch(Net::HTTP, [:request], :net, no_recurse: true)

        MethodProfiler.patch(Excon::Connection, [:request], :net)
        true
      end
  end
end
