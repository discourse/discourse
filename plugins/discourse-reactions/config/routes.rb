# frozen_string_literal: true

DiscourseReactions::Engine.routes.draw do
  get "/discourse-reactions/custom-reactions" => "custom_reactions#index",
      :constraints => {
        format: :json,
      }
  put "/discourse-reactions/posts/:post_id/custom-reactions/:reaction/toggle" =>
        "custom_reactions#toggle",
      :constraints => {
        format: :json,
      }
  get "/discourse-reactions/posts/reactions" => "custom_reactions#reactions_given",
      :as => "reactions_given"
  get "/discourse-reactions/posts/reactions-received" => "custom_reactions#reactions_received",
      :as => "reactions_received"
  get "/discourse-reactions/posts/:id/reactions-users" => "custom_reactions#post_reactions_users",
      :as => "post_reactions_users"
end
