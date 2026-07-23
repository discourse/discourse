# frozen_string_literal: true

DiscourseWorkflows::Engine.routes.draw do
  scope "/admin/plugins/discourse-workflows",
        as: "admin_discourse_workflows",
        constraints: AdminConstraint.new do
    scope format: false do
      get "/" => "admin#index"
      get "/variables" => "admin#index"
      get "/executions" => "admin#index"
      get "/templates" => "admin#index"
      get "/data-tables" => "admin#index"
      get "/data-tables/:id" => "admin#index", :constraints => { id: /\d+/ }
      get "/credentials" => "admin#index"
      get "/workflows/new" => "admin#index"
      get "/workflows/:id" => "admin#index", :constraints => { id: /\d+/ }
      get "/workflows/:id/executions" => "admin#index", :constraints => { id: /\d+/ }
      get "/workflows/:id/executions/:execution_id" => "admin#index",
          :constraints => {
            id: /\d+/,
            execution_id: /\d+/,
          }
      get "/workflows/:id/settings" => "admin#index", :constraints => { id: /\d+/ }
      get "/workflows/:id/versions" => "admin#index", :constraints => { id: /\d+/ }
    end

    scope format: :json do
      get "/workflows" => "workflows#index"
      post "/workflows" => "workflows#create"
      post "/workflows/ai/author" => "ai_authoring#create"
      post "/workflows/:workflow_id/ai/author" => "ai_authoring#create"
      post "/workflows/:workflow_id/ai/apply" => "ai_authoring#apply"
      get "/workflows/:id" => "workflows#show"
      put "/workflows/:id" => "workflows#update"
      post "/workflows/:id/discard-draft" => "workflows#discard_draft"
      put "/workflows/:id/pin-data" => "workflows#update_pin_data"
      post "/workflows/:id/form-test-sessions" => "form_test_sessions#create"
      post "/workflows/:id/webhook-test-listeners" => "webhook_test_listeners#create"
      delete "/workflows/:id/webhook-test-listeners/:listener_id" =>
               "webhook_test_listeners#destroy"
      delete "/workflows/:id" => "workflows#destroy"
      get "/node-types" => "node_types#index"
      get "/filter-options/posts" => "filter_options#posts"
      post "/dynamic-node-parameters/options" => "dynamic_node_parameters#options"
      get "/templates" => "templates#index"
      get "/templates/:id" => "templates#show"
      post "/executions" => "executions#create"
      post "/step-executions" => "step_executions#create"
      get "/executions" => "executions#index"
      get "/workflows/:workflow_id/executions" => "executions#index"
      get "/workflows/:workflow_id/versions" => "workflow_versions#index"
      post "/workflows/:workflow_id/versions/:version_id/restore" => "workflow_versions#restore",
           :constraints => {
             version_id: /[0-9a-f-]{36}/,
           }
      delete "/executions" => "executions#destroy"
      get "/executions/:id" => "executions#show"
      get "/stats" => "stats#index"
      get "/stats/:workflow_id" => "stats#index"
      post "/expressions/evaluate" => "expressions#evaluate"
      get "/variables" => "variables#index"
      post "/variables" => "variables#create"
      put "/variables/:id" => "variables#update"
      delete "/variables/:id" => "variables#destroy"
      get "/credentials" => "credentials#index"
      post "/credentials" => "credentials#create"
      put "/credentials/:id" => "credentials#update"
      delete "/credentials/:id" => "credentials#destroy"
      get "/data-tables" => "data_tables#index"
      post "/data-tables" => "data_tables#create"
      get "/data-tables/:id" => "data_tables#show", :constraints => { id: /\d+/ }
      put "/data-tables/:id" => "data_tables#update"
      delete "/data-tables/:id" => "data_tables#destroy"
      post "/data-tables/:data_table_id/columns" => "data_table_columns#create"
      patch "/data-tables/:data_table_id/columns/:column_name/rename" => "data_table_columns#rename"
      delete "/data-tables/:data_table_id/columns/:column_name" => "data_table_columns#destroy"
      get "/data-tables/:data_table_id/rows" => "data_table_rows#index"
      post "/data-tables/:data_table_id/rows" => "data_table_rows#create"
      put "/data-tables/:data_table_id/rows" => "data_table_rows#update_bulk"
      put "/data-tables/:data_table_id/rows/:id" => "data_table_rows#update"
      delete "/data-tables/:data_table_id/rows/:id" => "data_table_rows#destroy"
      delete "/data-tables/:data_table_id/rows" => "data_table_rows#destroy_bulk"
    end
  end

  scope "/discourse-workflows", defaults: { format: :json } do
    post "/trigger-topic-admin-button" => "topic_admin_button#create"
    post "/modal-responses" => "modal_responses#create"
  end

  scope "/workflows", defaults: { format: :json } do
    match "/waiting/:execution_id/webhook(/*suffix)" => "webhooks#receive",
          :via => :all,
          :constraints => {
            execution_id: /\d+/,
          }
    match "/webhook-test/:listener_id/*path" => "webhooks#receive_test", :via => :all
    match "/webhooks/*path" => "webhooks#receive", :via => :all
  end

  scope "/workflows/form", defaults: { format: :json } do
    get "/:uuid" => "forms#show",
        :constraints => {
          uuid: /[0-9a-f-]{36}/,
        },
        :defaults => {
          format: :html,
        }
    post "/:uuid" => "forms#create", :constraints => { uuid: /[0-9a-f-]{36}/ }
  end

  scope "/workflows/form-test", defaults: { format: :json } do
    get "/:token" => "forms#test_show",
        :constraints => {
          token: /[0-9a-f-]{36}/,
        },
        :defaults => {
          format: :html,
        }
    post "/:token" => "forms#test_create", :constraints => { token: /[0-9a-f-]{36}/ }
  end

  scope "/workflows/forms/waiting", defaults: { format: :json } do
    get "/:execution_id/status" => "forms#waiting_status", :constraints => { execution_id: /\d+/ }
    get "/:execution_id" => "forms#waiting_show", :constraints => { execution_id: /\d+/ }
    post "/:execution_id" => "forms#waiting_create", :constraints => { execution_id: /\d+/ }
  end
end

Discourse::Application.routes.draw { mount ::DiscourseWorkflows::Engine, at: "/" }
