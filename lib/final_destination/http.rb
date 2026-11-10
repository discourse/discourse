# frozen_string_literal: true

class FinalDestination::HTTP < Net::HTTP
  # Ruby's Happy Eyeballs implementation will try every IP address at 250ms intervals.
  # Limit the total to avoid DoS via a high-ip-count DNS response.
  MAX_ADDRESSES_PER_FAMILY = 5

  # Bounds reads by wall-clock time. read_timeout alone resets on every received
  # byte, so a peer trickling its response could otherwise hold the caller indefinitely.
  module DeadlineBufferedIO
    attr_accessor :deadline

    private

    def rbuf_fill
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise Net::ReadTimeout.new(io) if remaining <= 0
      self.read_timeout = remaining if read_timeout.nil? || read_timeout > remaining
      super
    end
  end

  # Maximum seconds a request may spend reading the response once connected, on top
  # of open_timeout. Unset by default.
  attr_accessor :total_timeout

  def connect
    raise ArgumentError.new("address cannot be nil or empty") if @address.blank?

    if !@ipaddr
      ips =
        FinalDestination::SSRFDetector.lookup_and_filter_ips(@address, timeout: @connect_timeout)

      if proxy?
        self.ipaddr = ips.first
      else
        @final_destination_token =
          FinalDestination::Connector.encode(@address, capped_addresses(ips))
      end
    end

    super
    apply_total_timeout
  ensure
    @final_destination_token = nil
  end

  def conn_address
    @final_destination_token || super
  end

  private

  def apply_total_timeout
    return if total_timeout.nil?

    @socket.extend(DeadlineBufferedIO)
    @socket.deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + total_timeout
  end

  def capped_addresses(ips)
    ipv6, ipv4 = ips.partition { |ip| ip.include?(":") }
    ipv6.first(MAX_ADDRESSES_PER_FAMILY) + ipv4.first(MAX_ADDRESSES_PER_FAMILY)
  end
end
