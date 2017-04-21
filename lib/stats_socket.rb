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

    start = Time.now
    line = ""

    while Time.now - start < 10
      if IO.select([socket], nil, nil, 10)
        begin
          line << socket.read_nonblock(1000)
        rescue IO::WaitReadable
          sleep 0.001
        end
      end
      break if line.include?("\n")
    end

    if line.include?("\n")
      socket.write get_response(line.strip)
    end

    true
  rescue IOError => e
    # nothing to do here, case its normal on shutdown
  rescue => e
    Rails.logger.warn("Failed to handle connection in stats socket #{e}")
  ensure
    socket&.close rescue nil
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
