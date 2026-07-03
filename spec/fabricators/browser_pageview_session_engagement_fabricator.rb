# frozen_string_literal: true

Fabricator(:browser_pageview_session_engagement) do
  session_id { SecureRandom.alphanumeric(32) }
  engaged_seconds 30
end
