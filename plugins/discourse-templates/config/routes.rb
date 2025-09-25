# frozen_string_literal: true

DiscourseTemplates::Engine.routes.draw do
  resources :templates, path: "/", only: [:index] do
    member { post "use" }
  end
end
