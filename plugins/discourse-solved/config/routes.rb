# frozen_string_literal: true

DiscourseSolved::Engine.routes.draw do
  post "/accept" => "answer#accept"
  post "/unaccept" => "answer#unaccept"

  post "/shared_issue" => "shared_issue#create"

  get "/by_user" => "solved_topics#by_user"
end

Discourse::Application.routes.draw do
  mount DiscourseSolved::Engine, at: "solution"

  get "/admin/plugins/solved/dashboard-support" => "discourse_solved/super_admin_dashboard_support#index",
      :constraints => StaffConstraint.new
end
