# frozen_string_literal: true

DiscourseRewind::Engine.routes.draw do
  get "/rewinds" => "rewinds#index"
  get "/rewinds/:index" => "rewinds#show"
end

Discourse::Application.routes.draw { mount ::DiscourseRewind::Engine, at: "/" }
