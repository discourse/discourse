# frozen_string_literal: true

DiscourseWireframe::Engine.routes.draw do
  # The admin Templates tab: a direct load renders the app shell, the tab fetches
  # its list as JSON.
  get "/admin/plugins/discourse-wireframe/wireframe-templates" => "block_layout_companions#index",
      :constraints => AdminConstraint.new
  scope "/admin/plugins/wireframe", as: "admin_wireframe", constraints: AdminConstraint.new do
    scope format: :json do
      get "/block-layout-drafts" => "block_layout_drafts#index"
      post "/block-layout-drafts" => "block_layout_drafts#create"
      delete "/block-layout-drafts" => "block_layout_drafts#destroy"
      post "/customization-component" => "block_layout_companions#create"
      get "/designs" => "block_layout_companions#index"
      get "/designs/:design_id" => "block_layout_companions#design"
      get "/companion" => "block_layout_companions#show"
      put "/companion" => "block_layout_companions#update"
      delete "/companion" => "block_layout_companions#destroy"
    end
  end
end

Discourse::Application.routes.draw { mount ::DiscourseWireframe::Engine, at: "/" }
