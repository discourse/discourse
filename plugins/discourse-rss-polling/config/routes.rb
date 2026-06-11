# frozen_string_literal: true

DiscourseRssPolling::Engine.routes.draw do
  root "feed_settings#show"

  post "feed_settings/test" => "feed_settings#test", :constraints => StaffConstraint.new
  resource :feed_settings, constraints: StaffConstraint.new, only: %i[show update destroy]
end

Discourse::Application.routes.draw do
  # Deep-link routes for the admin plugin show page so the Ember app loads on a
  # full-page navigation or refresh (`check_xhr` serves the SPA for HTML requests).
  scope "/admin/plugins/discourse-rss-polling", constraints: StaffConstraint.new do
    get "/feeds" => "discourse_rss_polling/feed_settings#index"
    get "/feeds/new" => "discourse_rss_polling/feed_settings#index"
    get "/feeds/:id/edit" => "discourse_rss_polling/feed_settings#index"
  end
end
