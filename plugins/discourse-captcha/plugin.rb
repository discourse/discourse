# coding: utf-8
# frozen_string_literal: true

# name: discourse-captcha
# about: Captcha support for Discourse (hCaptcha and reCaptcha)
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-captcha
# required_version: 2.7.0
# meta_topic_id: 291383

enabled_site_setting :discourse_captcha_enabled

register_svg_icon "hand"

module ::DiscourseCaptcha
  PLUGIN_NAME = "discourse-captcha"
end

require_relative "lib/discourse_captcha/engine"
require_relative "lib/discourse_captcha/captcha_provider"

after_initialize do
  reloadable_patch { UsersController.include(DiscourseCaptcha::CreateUsersControllerPatch) }

  require_relative "app/services/problem_check/hcaptcha_configuration"
  require_relative "app/services/problem_check/recaptcha_configuration"
  register_problem_check ProblemCheck::HcaptchaConfiguration
  register_problem_check ProblemCheck::RecaptchaConfiguration
end
