# frozen_string_literal: true

return unless defined?(Pitchfork::HttpServer)

# Pitchfork's monitor wakeup is a single-byte NOOP ("."). Coalesced reads
# like "..." aren't recognized and get logged as unexpected — treat any
# all-dots read as a NOOP.
module PitchforkSockStreamPatch
  def monitor_sleep(sec)
    @control_socket[0].wait(sec) or return
    case message = @control_socket[0].recvmsg_nonblock(exception: false)
    when :wait_readable
      nil
    when String
      @sig_queue << message unless message.match?(/\A\.+\z/)
    else
      @sig_queue << message
    end
  end
end

Pitchfork::HttpServer.prepend(PitchforkSockStreamPatch)
