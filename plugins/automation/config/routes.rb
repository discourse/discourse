# frozen_string_literal: true

DiscourseAutomation::Engine.routes.draw do
  scope format: :json, constraints: AdminConstraint.new do
    post "/automations/:id/trigger" => "automations#trigger"
  end

  scope format: :json do
    delete "/user-global-notices/:id" => "user_global_notices#destroy"
    put "/append-last-checked-by/:post_id" => "append_last_checked_by#post_checked"
  end

  scope "/admin/plugins/automation",
        as: "admin_discourse_automation",
        constraints: AdminConstraint.new do
    scope format: false do
      get "/automation" => "super_admin#index"
      get "/automation/new" => "super_admin#new"
      get "/automation/:id" => "super_admin#edit"
    end

    scope format: :json do
      get "/scriptables" => "super_admin_scriptables#index"
      get "/triggerables" => "super_admin_triggerables#index"
      get "/automations" => "super_admin_automations#index"
      get "/automations/:id" => "super_admin_automations#show"
      delete "/automations/:automation_id" => "super_admin_automations#destroy"
      put "/automations/:id" => "super_admin_automations#update"
      post "/automations" => "super_admin_automations#create"
    end
  end
end

Discourse::Application.routes.draw { mount ::DiscourseAutomation::Engine, at: "/" }
