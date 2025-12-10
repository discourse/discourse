# frozen_string_literal: true

DiscourseRewind::Engine.routes.draw do
  get "/rewinds" => "rewinds#index"
  get "/rewinds/:index" => "rewinds#show"
  put "/rewinds/toggle-share" => "rewinds#toggle_share"
end

Discourse::Application.routes.draw { mount ::DiscourseRewind::Engine, at: "/" }
