# frozen_string_literal: true

Hopper::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::Hopper::Engine, at: "hopper" }
