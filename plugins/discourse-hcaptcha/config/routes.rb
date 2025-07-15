# frozen_string_literal: true

Discourse::Application.routes.draw { mount ::DiscourseHcaptcha::Engine, at: "captcha" }

DiscourseHcaptcha::Engine.routes.draw { post "/hcaptcha/create" => "hcaptcha#create" }
DiscourseHcaptcha::Engine.routes.draw { post "/recaptcha/create" => "recaptcha#create" }
