# frozen_string_literal: true

DiscourseAutomation::Engine.routes.draw do
  scope format: :json, constraints: AdminConstraint.new do
    post "/automations/:id/trigger" => "automations#trigger"
  end

  scope format: :json do
    delete "/user-global-notices/:id" => "user_global_notices#destroy"
    put "/append-last-checked-by/:post_id" => "append_last_checked_by#post_checked"
  end

  scope "/admin/plugins/discourse-automation",
        as: "admin_discourse_automation",
        constraints: AdminConstraint.new do
    scope format: false do
      get "/" => "admin_discourse_automation#index"
      get "/new" => "admin_discourse_automation#new"
      get "/:id" => "admin_discourse_automation#edit"
    end

    scope format: :json do
      get "/scriptables" => "admin_discourse_automation_scriptables#index"
      get "/triggerables" => "admin_discourse_automation_triggerables#index"
      get "/automations" => "admin_discourse_automation_automations#index"
      get "/automations/:id" => "admin_discourse_automation_automations#show"
      delete "/automations/:id" => "admin_discourse_automation_automations#destroy"
      put "/automations/:id" => "admin_discourse_automation_automations#update"
      post "/automations" => "admin_discourse_automation_automations#create"
    end
  end
end

Discourse::Application.routes.append { mount ::DiscourseAutomation::Engine, at: "/" }
