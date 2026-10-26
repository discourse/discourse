# frozen_string_literal: true

# Reads the colors and fonts a website uses for its brand, so a site can be
# styled to match it.
#
#   profile = WebsiteBrand.profile("https://www.example.com")
#   profile&.brand # => "635bff"
#
# The page, its stylesheets, manifest and icon are fetched through
# FinalDestination, which refuses private and internal addresses. Nothing on
# the page runs, and the profile only holds typed values, so text from the
# page never reaches whatever uses it. Callers that fetch on a user's behalf
# should rate limit it.
module WebsiteBrand
  CACHE_LIFETIME = 1.day

  # Returns a WebsiteBrand::Profile, or nil when the page can't be read.
  # Profiles are cached for a day. Failures aren't, so a site that was briefly
  # down can be tried again.
  def self.profile(url)
    url = url.to_s.strip
    return if !url.match?(%r{\Ahttps?://}i)

    key = cache_key(url)
    cached = Discourse.cache.read(key)
    return cached if cached.is_a?(Profile)

    profile = Extractor.new(url).call
    Discourse.cache.write(key, profile, expires_in: CACHE_LIFETIME) if profile
    profile
  end

  def self.cache_key(url)
    "website_brand:#{Digest::SHA256.hexdigest(url)}"
  end
  private_class_method :cache_key
end
