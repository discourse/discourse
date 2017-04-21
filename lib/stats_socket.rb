require 'socket'

class StatsSocket

  def initialize(socket_path)
    @socket_path = socket_path
    @server = nil
  end

  def start
    @server = UNIXServer.new(@socket_path)
    @accept_thread = new_accept_thread
  end

  def stop
    @server.close if @server
    @server = nil
  end

  protected

  def new_accept_thread
    server = @server
    Thread.new do
      done = false
      while !done
        done = !accept_connection(server)
      end
    end
  end

  def accept_connection(server)
    socket = nil
    begin
      socket = server.accept
    rescue IOError
      # socket was shut down or something catastrophic like that happened
      return false
    end

    if IO.select(nil, [socket], nil, 10)
      line = socket.read_nonblock(1000)
      socket.write get_response(line.strip)
    end
    socket.close
    true
  rescue IOError
    # nothing to do here, case its normal on shutdown
  rescue => e
    Rails.logger.warn("Failed to handle connection in stats socket #{e}")
  end

  def get_response(command)
    result =
      case command
      when "gc_stat"
        GC.stat.to_json
      else
        "[\"UNKNOWN COMMAND\"]"
      end

    result << "\n"
  end

end
