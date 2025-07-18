# frozen_string_literal: true

Discourse::Application.routes.draw { mount ::DiscourseHcaptcha::Engine, at: "hcaptcha" }

DiscourseHcaptcha::Engine.routes.draw { post "/create" => "hcaptcha#create" }
