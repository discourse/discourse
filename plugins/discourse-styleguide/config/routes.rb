# frozen_string_literal: true

DiscourseStyleguide::Engine.routes.draw do
  get "/" => 'styleguide#index'
  get "/:category/:section" => 'styleguide#index'
end
