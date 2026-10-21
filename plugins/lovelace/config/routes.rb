# frozen_string_literal: true

Lovelace::Engine.routes.draw do
  get "/examples" => "examples#index"
  get "/admin/checklist" => "checklists#show"
  put "/admin/checklist" => "checklists#update"
end

Discourse::Application.routes.draw do
  mount ::Lovelace::Engine, at: "lovelace"
  get "/admin/plugins/lovelace/member-onboarding" => "admin/plugins#show",
      :defaults => {
        plugin_id: "lovelace",
      },
      :constraints => AdminConstraint.new
end
