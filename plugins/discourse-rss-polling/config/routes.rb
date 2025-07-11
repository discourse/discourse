# frozen_string_literal: true

DiscourseRssPolling::Engine.routes.draw do
  root "feed_settings#show"

  resource :feed_settings, constraints: StaffConstraint.new, only: %i[show update destroy]
end
