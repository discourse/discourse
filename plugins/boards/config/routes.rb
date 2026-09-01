# frozen_string_literal: true

Boards::Engine.routes.draw do
  namespace :api, defaults: { format: :json } do
    get "/boards" => "boards#index"
    get "/boards/available" => "boards#available"
    get "/boards/:id" => "boards#show"
    post "/boards" => "boards#create"
    put "/boards/:id" => "boards#update"
    delete "/boards/:id" => "boards#destroy"
    post "/boards/:id/move-column" => "boards#move_column"
    post "/boards/:id/constraint-preview" => "boards#constraint_preview"
    put "/boards/:id/check-constraint-mismatches" => "boards#check_constraint_mismatches"

    post "/boards/:board_id/columns" => "columns#create"
    put "/boards/:board_id/columns/:id" => "columns#update"
    delete "/boards/:board_id/columns/:id" => "columns#destroy"
    delete "/boards/:board_id/columns/:column_id/cards" => "cards#clear"

    post "/boards/:board_id/cards" => "cards#create"
    put "/boards/:board_id/cards/:id" => "cards#update"
    post "/boards/:board_id/cards/:id/view" => "cards#view"
    delete "/boards/:board_id/cards/:id" => "cards#destroy"

    post "/boards/:board_id/topic-moves" => "topic_moves#create"
  end

  get "/" => "boards#respond"
  get "/:slug/:id/configure" => "boards#respond"
  get "/:slug/:id/cards/:card_id" => "boards#respond"
  get "/:slug/:id" => "boards#respond"
end

Discourse::Application.routes.draw { mount ::Boards::Engine, at: "/boards" }
