# frozen_string_literal: true

DiscourseBoosts::Engine.routes.draw do
  post "/discourse-boosts/posts/:post_id/boosts" => "boosts#create",
       :constraints => {
         format: :json,
       }
  get "/discourse-boosts/boosts/:id" => "boosts#show", :constraints => { format: :json }
  delete "/discourse-boosts/boosts/:id" => "boosts#destroy", :constraints => { format: :json }
  post "/discourse-boosts/boosts/:id/flags" => "boosts#flag", :constraints => { format: :json }
  get "/discourse-boosts/users/:username/boosts-given" => "boosts#boosts_given",
      :constraints => {
        username: USERNAME_ROUTE_FORMAT,
        format: :json,
      }
  get "/discourse-boosts/users/:username/boosts-received" => "boosts#boosts_received",
      :constraints => {
        username: USERNAME_ROUTE_FORMAT,
        format: :json,
      }
end
