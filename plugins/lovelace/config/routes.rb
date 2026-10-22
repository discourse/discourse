# frozen_string_literal: true

Lovelace::Engine.routes.draw do
  get "/member-checklist" => "member_checklists#show"
  put "/member-checklist" => "member_checklists#update"
  get "/checklist" => "checklists#show"
  put "/checklist" => "checklists#update"
  get "/examples" => "examples#index"
  get "/admin/checklist" => "checklists#admin_show"
  put "/admin/checklist" => "checklists#admin_update"
end

Discourse::Application.routes.draw do
  mount ::Lovelace::Engine, at: "lovelace"
  get "/admin/plugins/lovelace/checklist" => "lovelace/checklists#configuration"
  get "/admin/plugins/lovelace/member-onboarding" => "admin/plugins#show",
      :defaults => {
        plugin_id: "lovelace",
      },
      :constraints => AdminConstraint.new
end
