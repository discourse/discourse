# frozen_string_literal: true

Discourse::Application.routes.draw do
  mount DiscourseCaptcha::Engine, at: "captcha"
end

DiscourseCaptcha::Engine.routes.draw do
  post "/hcaptcha/create" => "hcaptcha#create"
  post "/recaptcha/create" => "recaptcha#create"
end
