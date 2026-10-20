# frozen_string_literal: true

Lovelace::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::Lovelace::Engine, at: "lovelace" }
