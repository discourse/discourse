# coding: utf-8
# frozen_string_literal: true

# name: discourse-hcaptcha
# about: hCaptcha support for Discourse
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-hcaptcha
# required_version: 2.7.0
# meta_topic_id: 291383

enabled_site_setting :discourse_captcha_enabled

extend_content_security_policy(script_src: %w[https://hcaptcha.com])

module ::DiscourseHcaptcha
  PLUGIN_NAME = "discourse-hcaptcha"
end

require_relative "lib/discourse_hcaptcha/engine"
require_relative "lib/discourse_hcaptcha/captcha_provider"

after_initialize do
  reloadable_patch { UsersController.include(DiscourseHcaptcha::CreateUsersControllerPatch) }

  require_relative "app/services/problem_check/hcaptcha_configuration.rb"
  require_relative "app/services/problem_check/recaptcha_configuration.rb"
  register_problem_check ProblemCheck::HcaptchaConfiguration
  register_problem_check ProblemCheck::RecaptchaConfiguration
end
