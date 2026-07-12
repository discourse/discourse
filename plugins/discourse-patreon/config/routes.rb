# frozen_string_literal: true

Patreon::Engine.routes.draw do
  get "/rewards" => "patreon_super_admin#rewards", :constraints => AdminConstraint.new
  get "/list" => "patreon_super_admin#list", :constraints => AdminConstraint.new
  post "/list" => "patreon_super_admin#edit", :constraints => AdminConstraint.new
  delete "/list" => "patreon_super_admin#delete", :constraints => AdminConstraint.new
  post "/sync_groups" => "patreon_super_admin#sync_groups", :constraints => AdminConstraint.new
  post "/update_data" => "patreon_super_admin#update_data", :constraints => AdminConstraint.new
  post "/webhook" => "patreon_webhook#index"
end
