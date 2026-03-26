# frozen_string_literal: true

DiscourseWorkflows::Engine.routes.draw do
  scope "/admin/plugins/discourse-workflows",
        as: "admin_discourse_workflows",
        constraints: AdminConstraint.new do
    scope format: false do
      get "/" => "admin#index"
      get "/new" => "admin#index"
      get "/variables" => "admin#index"
      get "/executions" => "admin#index"
      get "/templates" => "admin#index"
      get "/data-tables" => "admin#index"
      get "/data-tables/:id" => "admin#index", :constraints => { id: /\d+/ }
      get "/:id" => "admin#index", :constraints => { id: /\d+/ }
      get "/:id/executions" => "admin#index", :constraints => { id: /\d+/ }
      get "/:id/executions/:execution_id" => "admin#index",
          :constraints => {
            id: /\d+/,
            execution_id: /\d+/,
          }
      get "/:id/settings" => "admin#index", :constraints => { id: /\d+/ }
    end

    scope format: :json do
      get "/workflows" => "workflows#index"
      post "/workflows" => "workflows#create"
      get "/workflows/:id" => "workflows#show"
      put "/workflows/:id" => "workflows#update"
      delete "/workflows/:id" => "workflows#destroy"
      get "/node-types" => "node_types#index"
      get "/templates" => "templates#index"
      get "/templates/:id" => "templates#show"
      post "/executions" => "executions#create"
      get "/executions" => "executions#index"
      get "/workflows/:workflow_id/executions" => "workflow_executions#index"
      delete "/executions" => "executions#destroy"
      get "/executions/:id" => "executions#show"
      get "/stats" => "stats#index"
      get "/stats/:workflow_id" => "stats#show"
      get "/variables" => "variables#index"
      post "/variables" => "variables#create"
      put "/variables/:id" => "variables#update"
      delete "/variables/:id" => "variables#destroy"
      get "/data-tables" => "data_tables#index"
      post "/data-tables" => "data_tables#create"
      get "/data-tables/:id" => "data_tables#show", :constraints => { id: /\d+/ }
      put "/data-tables/:id" => "data_tables#update"
      delete "/data-tables/:id" => "data_tables#destroy"
      get "/data-tables/:data_table_id/rows" => "data_tables#rows"
      post "/data-tables/:data_table_id/rows" => "data_tables#insert_row"
      put "/data-tables/:data_table_id/rows" => "data_tables#update_rows"
      put "/data-tables/:data_table_id/rows/:id" => "data_tables#update_row"
      delete "/data-tables/:data_table_id/rows/:id" => "data_tables#destroy_row"
      delete "/data-tables/:data_table_id/rows" => "data_tables#delete_rows"
    end
  end

  scope "/discourse-workflows", defaults: { format: :json } do
    post "/trigger-topic-admin-button" => "topic_admin_button#create"
  end

  scope "/workflows", defaults: { format: :json } do
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
    put "/:uuid" => "forms#update", :constraints => { uuid: /[0-9a-f-]{36}/ }
  end
end

Discourse::Application.routes.draw { mount ::DiscourseWorkflows::Engine, at: "/" }
