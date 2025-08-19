# frozen_string_literal: true

DiscourseAssign::Engine.routes.draw do
  put "/claim/:topic_id" => "assign#claim"
  put "/assign" => "assign#assign"
  put "/unassign" => "assign#unassign"
  get "/suggestions" => "assign#suggestions"
  get "/assigned" => "assign#assigned"
  get "/members/:group_name" => "assign#group_members"
end

Discourse::Application.routes.draw do
  mount ::DiscourseAssign::Engine, at: "/assign"

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
