# frozen_string_literal: true

DiscourseDataExplorer::Engine.routes.draw do
  root to: "query#index"
  get "queries" => "query#index"
  get "queries/:id" => "query#show"

  scope "/", defaults: { format: :json } do
    get "schema" => "query#schema"
    get "groups" => "query#groups"
    post "queries" => "query#create"
    put "queries/:id" => "query#update"
    delete "queries/:id" => "query#destroy"
    post "queries/:id/run" => "query#run", :constraints => { format: /(json|csv)/ }
  end
end

Discourse::Application.routes.draw do
  get "/g/:group_name/reports" => "discourse_data_explorer/query#group_reports_index"
  get "/g/:group_name/reports/:id" => "discourse_data_explorer/query#group_reports_show"
  post "/g/:group_name/reports/:id/run" => "discourse_data_explorer/query#group_reports_run"

  mount DiscourseDataExplorer::Engine, at: "/admin/plugins/explorer"
end
