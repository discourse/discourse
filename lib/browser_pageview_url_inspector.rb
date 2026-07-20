# frozen_string_literal: true

class BrowserPageviewUrlInspector
  MAX_LENGTH = 2000

  def self.normalize(raw_url)
    return nil if raw_url.blank?

    value = raw_url.to_s.strip
    return nil if value.match?(/[[:space:][:cntrl:]]/) || value.match?(/%(?![0-9a-f]{2})/i)

    uri = Addressable::URI.parse(value)
    return nil unless valid_uri?(uri)

    path = uri.path.to_s.sub(%r{/+\z}, "")
    path = "/" if path.empty?
    path.byteslice(0, MAX_LENGTH).scrub("")
  rescue Addressable::URI::InvalidURIError, ArgumentError, TypeError
    nil
  end

  def self.valid_uri?(uri)
    return false if uri.nil?

    if uri.scheme.present?
      %w[http https].include?(uri.scheme.downcase) && uri.host.present?
    else
      uri.host.blank? && uri.path.to_s.start_with?("/")
    end
  end
  private_class_method :valid_uri?
end
