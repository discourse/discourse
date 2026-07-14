# frozen_string_literal: true

require "io/nonblock"

class FinalDestination
  # Socket class for http.rb that SSRF-filters the resolved addresses on the calling
  # thread, then races the survivors (Happy Eyeballs, RFC 8305). http.rb still runs TLS
  # against the original hostname, so only vetted IPs are ever dialed.
  class SSRFSafeSocket
    # DNS responses are attacker-controlled; cap the connection fan-out.
    MAX_ADDRESSES_PER_FAMILY = 5

    CONNECT_TIMEOUT = 5

    def self.open(host, port, *)
      new(host, port).connect
    end

    def initialize(host, port)
      @host = host
      @port = port
    end

    def connect
      socket = race(vetted_addresses)
      socket.nonblock = false # http.rb reads and writes with blocking semantics
      socket
    end

    private

    def vetted_addresses
      ips = FinalDestination::SSRFDetector.lookup_and_filter_ips(@host)
      ipv6, ipv4 = ips.partition { |ip| ip.include?(":") }
      ipv6.first(MAX_ADDRESSES_PER_FAMILY) + ipv4.first(MAX_ADDRESSES_PER_FAMILY)
    end

    def race(addresses)
      in_flight = {}
      last_error = nil

      addresses.each do |ip|
        socket = new_socket(ip)
        sockaddr = Socket.pack_sockaddr_in(@port, ip)
        begin
          socket.connect_nonblock(sockaddr)
          return win(socket, in_flight)
        rescue IO::WaitWritable
          in_flight[socket] = sockaddr
        rescue SystemCallError => e
          socket.close
          last_error = e
        end
      end

      until in_flight.empty?
        _, writable, = IO.select(nil, in_flight.keys, nil, CONNECT_TIMEOUT)

        if writable.nil?
          in_flight.each_key(&:close)
          raise Errno::ETIMEDOUT, @host
        end

        writable.each do |socket|
          sockaddr = in_flight.delete(socket)
          begin
            socket.connect_nonblock(sockaddr)
          rescue Errno::EISCONN
          rescue SystemCallError => e
            socket.close
            last_error = e
            next
          end
          return win(socket, in_flight)
        end
      end

      raise last_error || Errno::ECONNREFUSED.new(@host)
    end

    def new_socket(ip)
      family = ip.include?(":") ? Socket::AF_INET6 : Socket::AF_INET
      Socket.new(family, Socket::SOCK_STREAM, 0)
    end

    def win(socket, losers)
      losers.each_key(&:close)
      socket
    end
  end
end
