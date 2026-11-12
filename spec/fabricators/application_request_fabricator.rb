# frozen_string_literal: true

Fabricator(:application_request) do
  transient request_type: :page_view_logged_in_browser

  date { Date.current }
  count 1
  req_type { |transients| ApplicationRequest.req_types.fetch(transients[:request_type].to_s) }
end

Fabricator(:logged_in_application_request, from: :application_request) do
  transient request_type: :page_view_logged_in
end

Fabricator(:anonymous_application_request, from: :application_request) do
  transient request_type: :page_view_anon
end

Fabricator(:logged_in_browser_application_request, from: :application_request) do
  transient request_type: :page_view_logged_in_browser
end

Fabricator(:logged_in_browser_mobile_application_request, from: :application_request) do
  transient request_type: :page_view_logged_in_browser_mobile
end

Fabricator(:logged_in_browser_beacon_application_request, from: :application_request) do
  transient request_type: :page_view_logged_in_browser_beacon
end

Fabricator(:anonymous_browser_application_request, from: :application_request) do
  transient request_type: :page_view_anon_browser
end

Fabricator(:anonymous_browser_mobile_application_request, from: :application_request) do
  transient request_type: :page_view_anon_browser_mobile
end

Fabricator(:anonymous_browser_beacon_application_request, from: :application_request) do
  transient request_type: :page_view_anon_browser_beacon
end

Fabricator(:embedded_application_request, from: :application_request) do
  transient request_type: :page_view_embed
end

Fabricator(:crawler_application_request, from: :application_request) do
  transient request_type: :page_view_crawler
end
