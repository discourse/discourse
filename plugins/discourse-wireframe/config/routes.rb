# frozen_string_literal: true

DiscourseWireframe::Engine.routes.draw do
  scope "/admin/plugins/wireframe", as: "admin_wireframe", constraints: AdminConstraint.new do
    scope format: :json do
      post "/block-layout-drafts" => "block_layout_drafts#create"
      delete "/block-layout-drafts" => "block_layout_drafts#destroy"
    end
  end
end

Discourse::Application.routes.draw { mount ::DiscourseWireframe::Engine, at: "/" }
