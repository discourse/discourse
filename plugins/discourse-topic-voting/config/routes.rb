# frozen_string_literal: true

DiscourseTopicVoting::Engine.routes.draw do
  post "vote" => "votes#vote"
  post "unvote" => "votes#unvote"
  get "who" => "votes#who"
end
