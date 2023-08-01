# frozen_string_literal: true

Regexp.timeout =
  GlobalSetting.regex_timeout_seconds.to_i if GlobalSetting.regex_timeout_seconds.present?
