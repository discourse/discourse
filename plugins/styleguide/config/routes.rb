# frozen_string_literal: true

Styleguide::Engine.routes.draw do
  get "/" => "styleguide#index"
  get "/design-variables" => "styleguide#design_variables", :defaults => { format: :json }
  get "/:category/:section" => "styleguide#index"
end
