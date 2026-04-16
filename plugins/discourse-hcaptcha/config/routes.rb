# frozen_string_literal: true

Discourse::Application.routes.draw { mount DiscourseHcaptcha::Engine, at: "captcha" }

DiscourseHcaptcha::Engine.routes.draw do
  post "/hcaptcha/create" => "hcaptcha#create"
  post "/recaptcha/create" => "recaptcha#create"
end
