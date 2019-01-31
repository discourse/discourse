require 'socket'

class SocketServer

  def initialize(socket_path)
    @socket_path = socket_path
    @server = nil
  end

  def start(&blk)
    @server = UNIXServer.new(@socket_path)
    @accept_thread = new_accept_thread
    if blk
      @blk = blk
    end
  end

  def stop
    @server&.close
    FileUtils.rm_f(@socket_path)
    @server = nil
    @blk = nil
  end

  protected

  def new_accept_thread
    server = @server
    Thread.new do
      begin
        done = false
        while !done
          done = !accept_connection(server)
        end
      ensure
        self.stop
        Rails.logger.info("Cleaned up socket server at #{@socket_path}")
      end
    end
  end

  def accept_connection(server)
    socket = nil
    begin
      socket = server.accept
    rescue IOError, Errno::EPIPE
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
  rescue IOError, Errno::EPIPE
    # nothing to do here, case its normal on shutdown
  rescue => e
    Rails.logger.warn("Failed to handle connection #{e}:\n#{e.backtrace.join("\n")}")
  ensure
    socket&.close
  end

  def get_response(command)
    if @blk
      @blk.call(command)
    else
      raise "Must be implemented by child"
    end
  end

end
