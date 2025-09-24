# frozen_string_literal: true

DiscourseUserNotes::Engine.routes.draw do
  get "/" => "user_notes#index"
  post "/" => "user_notes#create"
  delete "/:id" => "user_notes#destroy"
end
