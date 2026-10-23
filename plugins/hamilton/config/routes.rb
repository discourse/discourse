# frozen_string_literal: true

Hamilton::Engine.routes.draw do
  get "/" => "pages#index"
  get "/docs" => "pages#docs"
  get "/docs/guide" => "pages#guide"
  get "/docs/roadmap" => "pages#roadmap"
  get "/examples" => "examples#index"
end

Discourse::Application.routes.draw { mount ::Hamilton::Engine, at: "hamilton" }
