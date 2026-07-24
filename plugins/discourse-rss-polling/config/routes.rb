# frozen_string_literal: true

DiscourseRssPolling::Engine.routes.draw do
  post "feed_settings/test" => "feed_settings#test", :constraints => StaffConstraint.new
  get "feed_settings/category_requirements" => "feed_settings#category_requirements",
      :constraints => StaffConstraint.new
  get "feed_settings/:id/history" => "feed_settings#history", :constraints => StaffConstraint.new
  put "feed_settings/:id/enabled" => "feed_settings#set_enabled",
      :constraints => StaffConstraint.new
  post "feed_settings/:id/poll" => "feed_settings#poll", :constraints => StaffConstraint.new
  delete "feed_settings/:id" => "feed_settings#destroy", :constraints => StaffConstraint.new
  get "feed_settings/:id" => "feed_settings#feed", :constraints => StaffConstraint.new
  resource :feed_settings, constraints: StaffConstraint.new, only: %i[show update]
end

Discourse::Application.routes.draw do
  scope "/admin/plugins/discourse-rss-polling", constraints: StaffConstraint.new do
    get "/feeds(/*path)" => "discourse_rss_polling/feed_settings#index"
  end
end
