# frozen_string_literal: true

PostVoting::Engine.routes.draw do
  resource :vote
  get "voters" => "votes#voters"

  get "comments" => "comments#load_more_comments"
  get "comments/:id" => "comments#show"
  post "comments" => "comments#create"
  delete "comments" => "comments#destroy"
  put "comments" => "comments#update"
  put "comments/flag" => "comments#flag"
  post "vote/comment" => "votes#create_comment_vote"
  delete "vote/comment" => "votes#destroy_comment_vote"
end

Discourse::Application.routes.append { mount PostVoting::Engine, at: "post_voting" }

# Route for comment permalinks - forwards to topics#show so Ember app loads and handles client-side routing
Discourse::Application.routes.append do
  get "t/:slug/:topic_id/comment/:comment_id" => "topics#show",
      :constraints => {
        topic_id: /\d+/,
        comment_id: /\d+/,
      }
end
