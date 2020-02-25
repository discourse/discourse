# frozen_string_literal: true

module WildcardUrlChecker
  def self.check_url(url, url_to_check)
    return false if !valid_url?(url_to_check)

    escaped_url = Regexp.escape(url).sub("\\*", '\S*')
    url_regex = Regexp.new("\\A#{escaped_url}\\z", 'i')

    url_to_check.match?(url_regex)
  end

  private

  def self.valid_url?(url)
    uri = URI.parse(url)
    uri&.scheme.present? && uri&.host.present?
  rescue URI::InvalidURIError
    false
  end
end
