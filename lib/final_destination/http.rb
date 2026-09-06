# frozen_string_literal: true

class FinalDestination::HTTP < Net::HTTP
  # Ruby's Happy Eyeballs implementation will try every IP address at 250ms intervals.
  # Limit the total to avoid DoS via a high-ip-count DNS response.
  MAX_ADDRESSES_PER_FAMILY = 5

  def connect
    raise ArgumentError.new("address cannot be nil or empty") if @address.blank?
    return super if @ipaddr

    ips = FinalDestination::SSRFDetector.lookup_and_filter_ips(@address, timeout: @connect_timeout)

    if proxy?
      self.ipaddr = ips.first
      return super
    end

    @final_destination_token = FinalDestination::Connector.encode(@address, capped_addresses(ips))
    super
  ensure
    @final_destination_token = nil
  end

  def conn_address
    @final_destination_token || super
  end

  private

  def capped_addresses(ips)
    ipv6, ipv4 = ips.partition { |ip| ip.include?(":") }
    ipv6.first(MAX_ADDRESSES_PER_FAMILY) + ipv4.first(MAX_ADDRESSES_PER_FAMILY)
  end
end
