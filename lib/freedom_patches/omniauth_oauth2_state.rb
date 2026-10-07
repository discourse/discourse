# frozen_string_literal: true

require "omniauth-oauth2"

# `secure_compare` calls `bytesize` on both sides, so a callback that arrives
# with no `omniauth.state` in the session raises instead of failing the CSRF
# check. https://github.com/omniauth/omniauth-oauth2/pull/186 fixes it upstream.
module OmniAuthOAuth2StatePatch
  def secure_compare(string_a, string_b)
    return false if string_a.to_s.empty? || string_b.to_s.empty?
    super
  end
end

OmniAuth::Strategies::OAuth2.prepend(OmniAuthOAuth2StatePatch)
