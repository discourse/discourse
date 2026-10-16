# frozen_string_literal: true

Discourse::Application.routes.draw { mount DiscourseCaptcha::Engine, at: "captcha" }

DiscourseCaptcha::Engine.routes.draw do
  post "/hcaptcha/create", to: "hcaptcha#create"
  post "/recaptcha/create", to: "recaptcha#create"
  post "/recaptcha_v2/create", to: "recaptcha#create"
  post "/recaptcha_v3/create", to: "recaptcha_v3#create"
end
