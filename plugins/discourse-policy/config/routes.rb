# frozen_string_literal: true

DiscoursePolicy::Engine.routes.draw do
  put "/accept" => "policy#accept"
  put "/unaccept" => "policy#unaccept"
  get "/accepted" => "policy#accepted"
  get "/not-accepted" => "policy#not_accepted"
end
