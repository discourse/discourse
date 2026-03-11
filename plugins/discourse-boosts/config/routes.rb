# frozen_string_literal: true

DiscourseBoosts::Engine.routes.draw do
  post "/discourse-boosts/posts/:post_id/boosts" => "boosts#create",
       :constraints => {
         format: :json,
       }
  delete "/discourse-boosts/boosts/:id" => "boosts#destroy", :constraints => { format: :json }
  get "/discourse-boosts/users/:username/boosts" => "boosts#index",
      :constraints => {
        username: USERNAME_ROUTE_FORMAT,
        format: :json,
      }
end
