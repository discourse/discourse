# frozen_string_literal: true

DiscoursePoll::Engine.routes.draw do
  put "/vote" => "polls#vote"
  delete "/vote" => "polls#remove_vote"
  put "/toggle_status" => "polls#toggle_status"
  get "/voters" => "polls#voters"
  get "/grouped_poll_results" => "polls#grouped_poll_results"
end
