# frozen_string_literal: true

Fabricator(:browser_pageview_event) do
  url "https://example.com/"
  ip_address "1.2.3.4"
  user_agent "test"
  session_id { SecureRandom.hex(16) }
end
