# frozen_string_literal: true

Styleguide::Engine.routes.draw do
  get "/" => "styleguide#index"
  get "/:category/:section" => "styleguide#index"
end
