# frozen_string_literal: true

DiscourseGamification::Engine.routes.draw do
  get "/" => "gamification_leaderboard#respond"
  get "/:id" => "gamification_leaderboard#respond"
end

Discourse::Application.routes.draw do
  mount ::DiscourseGamification::Engine, at: "/leaderboard"

  scope "/admin/plugins/discourse-gamification", constraints: StaffConstraint.new do
    get "/leaderboards" => "discourse_gamification/admin_gamification_leaderboard#index"
    get "/leaderboards/:id" => "discourse_gamification/admin_gamification_leaderboard#show"
  end

  get "/admin/plugins/gamification" =>
        "discourse_gamification/admin_gamification_leaderboard#index",
      :constraints => StaffConstraint.new
  post "/admin/plugins/gamification/leaderboard" =>
         "discourse_gamification/admin_gamification_leaderboard#create",
       :constraints => StaffConstraint.new
  put "/admin/plugins/gamification/leaderboard/:id" =>
        "discourse_gamification/admin_gamification_leaderboard#update",
      :constraints => StaffConstraint.new
  delete "/admin/plugins/gamification/leaderboard/:id" =>
           "discourse_gamification/admin_gamification_leaderboard#destroy",
         :constraints => StaffConstraint.new
  put "/admin/plugins/gamification/recalculate-scores" =>
        "discourse_gamification/admin_gamification_leaderboard#recalculate_scores",
      :constraints => StaffConstraint.new,
      :as => :recalculate_scores
end

Discourse::Application.routes.draw do
  get "/admin/plugins/gamification/score_events" =>
        "discourse_gamification/admin_gamification_score_event#show",
      :constraints => StaffConstraint.new
  post "/admin/plugins/gamification/score_events" =>
         "discourse_gamification/admin_gamification_score_event#create",
       :constraints => StaffConstraint.new
  put "/admin/plugins/gamification/score_events" =>
        "discourse_gamification/admin_gamification_score_event#update",
      :constraints => StaffConstraint.new
end
