# frozen_string_literal: true

Fabricator(:web_crawler_request) do
  user_agent { sequence(:ua) { |i| "Googlebot #{i}.0" } }
  date Time.zone.now.to_date
  count 0
end
