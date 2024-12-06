# frozen_string_literal: true

require "middleware/request_tracker"

Middleware::RequestTracker.rate_limit_bucketizer_register(
  priority: 0,
  identifier: :static_ip_skipper,
  blk: ->(request, _) do
    if Middleware::RequestTracker::STATIC_IP_SKIPPER&.any? { |net| net.include?(request.ip) }
      :skip
    else
      nil
    end
  end,
)

def is_private_ip?(ip)
  ip = IPAddr.new(ip)
  !!(ip && (ip.private? || ip.loopback?))
rescue IPAddr::AddressFamilyError, IPAddr::InvalidAddressError
  false
end

Middleware::RequestTracker.rate_limit_bucketizer_register(
  priority: 0,
  identifier: :private_ip_skipper,
  blk: ->(request, _) do
    # skip rate limiting altogether on private addresses (if enabled)
    if !GlobalSetting.max_reqs_rate_limit_on_private && is_private_ip?(request.ip)
      :skip
    else
      nil
    end
  end,
)

Middleware::RequestTracker.rate_limit_bucketizer_register(
  priority: 100,
  identifier: :cookie_authenticated_user,
  blk: ->(request, cookie) do
    # authenticated user?
    if cookie && cookie[:user_id] && cookie[:trust_level]
      if cookie[:trust_level] >= GlobalSetting.skip_per_ip_rate_limit_trust_level
        return "id/#{cookie[:user_id]}", false, "id", "user"
      else
        # if the authenticated user comes from another aggregate source
        # but does not meet skip_per_ip_rate_limit_trust_level
        # we don't want to bucket them along with the rest of that source,
        # so they still get bucketed by IP
        return "ip/#{request.ip}", true, "ip", "IP address"
      end
    end
    nil
  end,
)

Middleware::RequestTracker.rate_limit_bucketizer_register(
  priority: 1_000_000_000,
  identifier: :fallback_ip,
  blk: ->(request, _) { ["ip/#{request.ip}", true, "ip", "IP address"] },
)
