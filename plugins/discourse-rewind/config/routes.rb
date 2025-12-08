# frozen_string_literal: true

DiscourseRewind::Engine.routes.draw { get "/rewinds" => "rewinds#show" }

Discourse::Application.routes.draw { mount ::DiscourseRewind::Engine, at: "/" }
