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
      get "/" => "admin#index"
      get "/new" => "admin#new"
      get "/:id" => "admin#edit"
    end

    scope format: :json do
      get "/scriptables" => "admin_scriptables#index"
      get "/triggerables" => "admin_triggerables#index"
      get "/automations" => "admin_automations#index"
      get "/automations/:id" => "admin_automations#show"
      delete "/automations/:automation_id" => "admin_automations#destroy"
      put "/automations/:id" => "admin_automations#update"
      post "/automations" => "admin_automations#create"
    end
  end
end

Discourse::Application.routes.draw { mount ::DiscourseAutomation::Engine, at: "/" }
