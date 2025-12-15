# frozen_string_literal: true

DiscourseRewind::Engine.routes.draw do
  get "/rewinds" => "rewinds#index"
  get "/rewinds/:index" => "rewinds#show"
  post "/rewinds/dismiss" => "rewinds#dismiss"
end

Discourse::Application.routes.draw { mount ::DiscourseRewind::Engine, at: "/" }
