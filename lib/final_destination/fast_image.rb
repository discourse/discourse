# frozen_string_literal: true

class FinalDestination::FastImage < ::FastImage
  def initialize(url, options = {})
    uri = URI(normalized_url(url))
    options.merge!(http_header: { "Host" => uri.hostname })
    uri.hostname = resolved_ip(uri)

    super(uri.to_s, options)
  rescue FinalDestination::SSRFDetector::DisallowedIpError, SocketError, Timeout::Error
    super("")
  end

  private

  def resolved_ip(uri)
    FinalDestination::SSRFDetector.lookup_and_filter_ips(uri.hostname).first
  end

  def normalized_url(uri)
    UrlHelper.normalized_encode(uri)
  end
end
