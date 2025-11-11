# frozen_string_literal: true

DiscourseCakeday::Engine.routes.draw do
  get "birthdays" => "birthdays#index"
  get "birthdays/:filter" => "birthdays#index"
  get "anniversaries" => "anniversaries#index"
  get "anniversaries/:filter" => "anniversaries#index"
end
