# frozen_string_literal: true

DiscourseDataExplorer::Engine.routes.draw do
  root to: "query#index"
  get "queries" => "query#index"
  get "queries/new" => "query#index"
  get "queries/:id" => "query#show", :constraints => { id: /-?\d+/ }

  scope "/", defaults: { format: :json } do
    get "schema" => "query#schema"
    get "groups" => "query#groups"
    post "queries/generate" => "query#generate_with_ai"
    post "queries/preview" => "query#preview"
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

  # Public API to fetch query results via GET with permission checks
  get "/data-explorer/queries/:id/run" => "discourse_data_explorer/query#public_run",
      :constraints => {
        format: /(json|csv)/,
      }

  # JSON:API modernization spike (Graphiti) — read-only, public-shaped.
  # See docs/api-modernization-exploration.md.
  scope "/data-explorer/api/v1", defaults: { format: :jsonapi } do
    get "queries" => "discourse_data_explorer/api/v1/queries#index"
    get "queries/:id" => "discourse_data_explorer/api/v1/queries#show",
        :constraints => {
          id: /\d+/,
        }
    post "queries" => "discourse_data_explorer/api/v1/queries#create"
  end

  # Thin-layers alternative (jsonapi.rb) being compared against the Graphiti
  # endpoint above. See docs/api-modernization-exploration.md (Part 9).
  scope "/data-explorer/jsonapi-rb", defaults: { format: :json } do
    get "queries" => "discourse_data_explorer/jsonapi_rb/queries#index"
    get "queries/:id" => "discourse_data_explorer/jsonapi_rb/queries#show",
        :constraints => {
          id: /\d+/,
        }
    post "queries" => "discourse_data_explorer/jsonapi_rb/queries#create"
  end

  mount DiscourseDataExplorer::Engine, at: "/admin/plugins/discourse-data-explorer"
  get "/admin/plugins/explorer" => redirect("/admin/plugins/discourse-data-explorer")
  get "/admin/plugins/explorer/queries" =>
        redirect("/admin/plugins/discourse-data-explorer/queries")
  get "/admin/plugins/explorer/queries/:id" =>
        redirect("/admin/plugins/discourse-data-explorer/queries/%{id}")

  # Legacy /admin/plugins/explorer/ API routes - route directly to controller
  # since redirects don't preserve POST/PUT/DELETE request bodies
  scope "/", defaults: { format: :json } do
    get "/admin/plugins/explorer/schema" => "discourse_data_explorer/query#schema"
    get "/admin/plugins/explorer/groups" => "discourse_data_explorer/query#groups"
    post "/admin/plugins/explorer/queries/generate" =>
           "discourse_data_explorer/query#generate_with_ai"
    post "/admin/plugins/explorer/queries/preview" => "discourse_data_explorer/query#preview"
    post "/admin/plugins/explorer/queries" => "discourse_data_explorer/query#create"
    put "/admin/plugins/explorer/queries/:id" => "discourse_data_explorer/query#update"
    delete "/admin/plugins/explorer/queries/:id" => "discourse_data_explorer/query#destroy"
    post "/admin/plugins/explorer/queries/:id/run" => "discourse_data_explorer/query#run",
         :constraints => {
           format: /(json|csv)/,
         }
  end
end
