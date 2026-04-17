# frozen_string_literal: true

# Runs the same block of work against each of a set of multisite databases,
# optionally in parallel across forked workers. Output produced by the block
# for each database is prefixed with that database's name and flushed in the
# order the databases were given, so progress is visible as the run unfolds.
#
# Example:
#
#   MultisiteParallelRunner
#     .new(databases: RailsMultisite::ConnectionManagement.all_dbs, concurrency: 4)
#     .run do |db|
#       puts "Migrating #{db}"
#       execute_db_migration
#     end
class MultisiteParallelRunner
  Worker = Struct.new(:pid, :dbs, :pipe, :status, keyword_init: true)

  def initialize(databases:, concurrency:)
    @databases = databases
    @concurrency = concurrency
  end

  def run(&block)
    if should_fork?
      run_forked(&block)
    else
      run_inline(&block)
    end
  end

  private

  def should_fork?
    @concurrency > 1 && @databases.length > 1
  end

  def run_forked(&block)
    Discourse.before_fork
    workers = spawn_workers(&block)

    results = {}
    errors = {}
    mutex = Mutex.new
    next_index = 0

    readers =
      workers.map do |w|
        Thread.new do
          begin
            loop do
              # reading from a pipe connected to a worker we forked ourselves,
              # not adversarial input
              db, output, error = Marshal.load(w.pipe) # rubocop:disable Security/MarshalLoad
              mutex.synchronize do
                results[db] = output
                errors[db] = error if error
                while next_index < @databases.length && results.key?(@databases[next_index])
                  flush(@databases[next_index], results[@databases[next_index]])
                  next_index += 1
                end
              end
            end
          rescue EOFError, ArgumentError, TypeError
            # Pipe closed cleanly (EOFError), or the worker died mid-write
            # leaving a truncated marshal stream (ArgumentError/TypeError
            # from Marshal.load on partial input). In both cases we rely on
            # Process::Status to report the crash.
          ensure
            w.pipe.close unless w.pipe.closed?
          end
        end
      end

    workers.each { |w| _, w.status = Process.wait2(w.pid) }
    readers.each(&:join)

    mutex.synchronize do
      while next_index < @databases.length
        db = @databases[next_index]
        if results.key?(db)
          flush(db, results[db])
        else
          puts "[#{db}] (no output received from worker)"
        end
        next_index += 1
      end
    end

    failed = workers.reject { |w| w.status.success? }
    return if failed.empty?

    report_forked_failures(failed)
    first_error = errors.values.first
    raise first_error if first_error
    raise "Parallel multisite run failed"
  end

  def run_inline(&block)
    @databases.each do |db|
      RailsMultisite::ConnectionManagement.with_connection(db) { block.call(db) }
    end
  end

  def spawn_workers(&block)
    slices = Array.new(@concurrency) { [] }
    @databases.each_with_index { |db, i| slices[i % @concurrency] << db }

    slices
      .reject(&:empty?)
      .map do |dbs|
        parent_read, child_write = IO.pipe

        pid =
          Process.fork do
            parent_read.close
            Discourse.after_fork
            run_worker_slice(dbs, child_write, &block)
          end

        child_write.close
        Worker.new(pid: pid, dbs: dbs, pipe: parent_read)
      end
  end

  def run_worker_slice(dbs, pipe, &block)
    dbs.each do |db|
      output = StringIO.new
      begin
        $stdout = $stderr = output
        RailsMultisite::ConnectionManagement.with_connection(db) { block.call(db) }
        Marshal.dump([db, output.string, nil], pipe)
      rescue => e
        output.puts e.full_message
        Marshal.dump([db, output.string, marshalable_exception(e)], pipe)
        pipe.close
        exit 1
      ensure
        $stdout = STDOUT
        $stderr = STDERR
      end
    end
    pipe.close
  end

  # Some exceptions carry non-marshalable state (e.g. IO objects,
  # bindings). Fall back to a plain RuntimeError that preserves the
  # original class name, message, and backtrace.
  def marshalable_exception(exception)
    Marshal.dump(exception)
    exception
  rescue TypeError
    wrapped = RuntimeError.new("#{exception.class}: #{exception.message}")
    wrapped.set_backtrace(exception.backtrace)
    wrapped
  end

  def flush(db, output)
    output.each_line { |line| puts "[#{db}] #{line}" }
  end

  def report_forked_failures(failed)
    $stderr.puts
    $stderr.puts "-" * 80
    $stderr.puts "#{failed.length} worker(s) failed!"
    failed.each do |w|
      s = w.status
      reason = s.signaled? ? "killed by SIG#{Signal.signame(s.termsig)}" : "exited #{s.exitstatus}"
      $stderr.puts "  pid=#{w.pid} #{reason} (assigned: #{w.dbs.join(", ")})"
    end
  end
end
