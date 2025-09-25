# frozen_string_literal: true

AdPlugin::Engine.routes.draw do
  root to: "house_ads#index"
  resources :house_creatives, except: %i[new edit], controller: "house_ads"
  resources :house_settings, only: [:update], controller: "house_ad_settings"
end
