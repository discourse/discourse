# frozen_string_literal: true

DiscourseNarrativeBot::Engine.routes.draw do
  get "/certificate" => "certificates#generate", :format => :svg
end

Discourse::Application.routes.draw { mount ::DiscourseNarrativeBot::Engine, at: "/discobot" }
