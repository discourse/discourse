# frozen_string_literal: true

DiscourseSolved::Engine.routes.draw do
  post "/accept" => "answer#accept"
  post "/unaccept" => "answer#unaccept"

  get "/by_user" => "solved_topics#by_user"
end

Discourse::Application.routes.draw { mount DiscourseSolved::Engine, at: "solution" }
