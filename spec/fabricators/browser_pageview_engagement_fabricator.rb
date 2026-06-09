# frozen_string_literal: true

Fabricator(:browser_pageview_engagement) do
  event { Fabricate(:browser_pageview_event) }
end
