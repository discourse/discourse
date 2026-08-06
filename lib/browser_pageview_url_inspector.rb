# frozen_string_literal: true

class BrowserPageviewUrlInspector
  VERSION = 1
  MAX_LENGTH = 2000

  def self.normalize(raw)
    return nil if raw.blank?

    uri = Addressable::URI.parse(raw.to_s.strip)
    return nil if uri.scheme.present? && (!%w[http https].include?(uri.scheme) || uri.host.blank?)

    path = uri.path.to_s
    path = "/#{path}" if !path.start_with?("/")
    path = path.sub(%r{/+\z}, "")
    path = "/" if path.blank?
    path.byteslice(0, MAX_LENGTH).scrub("")
  rescue Addressable::URI::InvalidURIError, ArgumentError, TypeError
    nil
  end
end
