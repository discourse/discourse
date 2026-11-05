# frozen_string_literal: true

DiscourseAssign::Engine.routes.draw do
  get "/topics/:topic_id/assignments" => "assign#topic_assignments"
  put "/topics/:topic_id/assignments" => "assign#replace_topic_assignments"
  post "/topics/:topic_id/assignments" => "assign#add_topic_assignment"
  patch "/assignments/:id" => "assign#update_assignment"
  delete "/assignments/:id" => "assign#remove_assignment"
  put "/claim/:topic_id" => "assign#claim"
  put "/assign" => "assign#assign"
  put "/unassign" => "assign#unassign"
  get "/suggestions" => "assign#suggestions"
  get "/search" => "assign#search"
  get "/assigned" => "assign#assigned"
  get "/members/:group_name" => "assign#group_members"
end

Discourse::Application.routes.draw do
  mount DiscourseAssign::Engine, at: "/assign"

  get "topics/private-messages-assigned/:username" => "list#private_messages_assigned",
      :as => "topics_private_messages_assigned",
      :constraints => {
        username: ::RouteFormat.username,
      }
  get "/topics/messages-assigned/:username" => "list#messages_assigned",
      :constraints => {
        username: ::RouteFormat.username,
      },
      :as => "messages_assigned"
  get "/topics/group-topics-assigned/:groupname" => "list#group_topics_assigned",
      :constraints => {
        username: ::RouteFormat.username,
      },
      :as => "group_topics_assigned"
  get "/g/:id/assigned" => "groups#index"
  get "/g/:id/assigned/:route_type" => "groups#index"
end
