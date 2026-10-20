# frozen_string_literal: true

Hamilton::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::Hamilton::Engine, at: "hamilton" }
