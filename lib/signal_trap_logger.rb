# frozen_string_literal: true

# This class is used to log messages to a specified logger from within a `Signal.trap` context. Most loggers rely on
# methods that are prohibited within a `Signal.trap` context, so this class is used to queue up log messages and then
# log them from a separate thread outside of the `Signal.trap` context.
#
# Example:
#   Signal.trap("USR1") do
#     SignalTrapLogger.instance.log(Rails.logger, "Received USR1 signal")
#   end
#
# Do note that you need to call `SignalTrapLogger.instance.after_fork` after forking a new process to ensure that the
# logging thread is running in the new process.
class SignalTrapLogger
  include Singleton

  def initialize
    @queue = Queue.new
    ensure_logging_thread_running
  end

  def log(logger, message, level: :info)
    @queue << { logger:, message:, level: }
  end

  def after_fork
    ensure_logging_thread_running
  end

  private

  def ensure_logging_thread_running
    return if @thread&.alive?

    @thread =
      Thread.new do
        loop do
          begin
            log_entry = @queue.pop
            log_entry[:logger].public_send(log_entry[:level], log_entry[:message])
          rescue => error
            Rails.logger.error(
              "Error in SignalTrapLogger thread: #{error.message}\n#{error.backtrace.join("\n")}",
            )
          end
        end
      end
  end
end
