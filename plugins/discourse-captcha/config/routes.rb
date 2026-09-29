# frozen_string_literal: true

Discourse::Application.routes.draw do
  mount DiscourseCaptcha::Engine, at: "captcha"

  scope "/admin/plugins/discourse-captcha", constraints: AdminConstraint.new do
    get "/test" => "discourse_captcha/admin_captcha#show"
    post "/test" => "discourse_captcha/admin_captcha#verify"
  end
end

DiscourseCaptcha::Engine.routes.draw do
  post "/hcaptcha/create", to: "hcaptcha#create"
  post "/recaptcha/create", to: "recaptcha#create"
end
