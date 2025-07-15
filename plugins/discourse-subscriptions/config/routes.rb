# frozen_string_literal: true
require_dependency "subscriptions_user_constraint"

DiscourseSubscriptions::Engine.routes.draw do
  scope "admin" do
    get "/" => "admin#index"
    post "/refresh" => "admin#refresh_campaign"
    post "/create-campaign" => "admin#create_campaign"
  end

  namespace :admin, constraints: AdminConstraint.new do
    resources :plans
    resources :subscriptions, only: %i[index destroy]
    resources :products
    resources :coupons, only: %i[index create]
    resource :coupons, only: %i[destroy update]
  end

  namespace :user do
    resources :payments, only: [:index]
    resources :subscriptions, only: %i[index update destroy]
  end

  get "/" => "subscribe#index"
  get ".json" => "subscribe#index"
  get "/contributors" => "subscribe#contributors"
  get "/:id" => "subscribe#show"
  post "/create" => "subscribe#create"
  post "/finalize" => "subscribe#finalize"

  post "/hooks" => "hooks#create"
end
