# frozen_string_literal: true

DiscourseWireframe::Engine.routes.draw do
  scope "/admin/plugins/wireframe", as: "admin_wireframe", constraints: AdminConstraint.new do
    scope format: :json do
      get "/block-layout-drafts" => "block_layout_drafts#index"
      post "/block-layout-drafts" => "block_layout_drafts#create"
      delete "/block-layout-drafts" => "block_layout_drafts#destroy"
      post "/customization-component" => "block_layout_companions#create"
      get "/companion" => "block_layout_companions#show"
    end
  end
end

Discourse::Application.routes.draw { mount ::DiscourseWireframe::Engine, at: "/" }
