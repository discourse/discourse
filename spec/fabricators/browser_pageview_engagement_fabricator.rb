# frozen_string_literal: true

Fabricator(:browser_pageview_engagement) { event { Fabricate(:browser_pageview_event) } }
