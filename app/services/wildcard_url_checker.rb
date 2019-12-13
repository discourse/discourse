# frozen_string_literal: true

module WildcardUrlChecker
  VALID_PROTOCOLS = %w(http https discourse).freeze

  def self.check_url(url, url_to_check)
    return nil if !valid_url?(url_to_check)

    escaped_url = Regexp.escape(url).sub("\\*", '\S*')
    url_regex = Regexp.new("\\A#{escaped_url}\\z", 'i')

    url_to_check.match(url_regex)
  end

  private

  def self.valid_url?(url)
    uri = URI.parse(url)
    VALID_PROTOCOLS.include?(uri&.scheme) && uri&.host.present?
  rescue URI::InvalidURIError
    false
  end
end
