# frozen_string_literal: true

class FinalDestination::HTTP < Net::HTTP
  def initialize(*args, &block)
    super(*args, &block)

    ## START PATCH
    # Remove this patch once https://github.com/ruby/net-http/commit/fed3dcd0c2b1270a1f0eb9c4a58bed8497989c9a has been
    # released in a new `net-http` version. See `config/initializers/100-http.rb` for more information.
    self.read_timeout = GlobalSetting.http_read_timeout_seconds.to_f
    self.open_timeout = GlobalSetting.http_open_timeout_seconds.to_f
    self.write_timeout = GlobalSetting.http_write_timeout_seconds.to_f
    ## END PATCH
  end

  def connect
    raise ArgumentError.new("address cannot be nil or empty") if @address.blank?

    original_open_timeout = @open_timeout
    return super if @ipaddr

    timeout_at = current_time + @open_timeout

    # This iteration through addresses would normally happen in Socket#tcp
    # We do it here because we're tightly controlling addresses rather than
    # handing Socket#tcp a hostname
    ips = FinalDestination::SSRFDetector.lookup_and_filter_ips(@address, timeout: @connect_timeout)

    ips.each_with_index do |ip, index|
      debug "[FinalDestination] Attempting connection to #{ip}..."
      self.ipaddr = ip

      remaining_time = timeout_at - current_time
      if remaining_time <= 0
        raise Net::OpenTimeout.new("Operation timed out - FinalDestination::HTTP")
      end

      @open_timeout = remaining_time
      return super
    rescue OpenSSL::SSL::SSLError, SystemCallError, Net::OpenTimeout => e
      debug "[FinalDestination] Error connecting to #{ip}... #{e.message}"
      was_last_attempt = index == ips.length - 1
      raise if was_last_attempt
    end
  ensure
    @open_timeout = original_open_timeout
  end

  private

  def current_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
