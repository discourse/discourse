# frozen_string_literal: true

module MobileDetection
  # if the criteria for mobile_device? changes, update the code for `isMobileDevice` in
  # `frontend/discourse/app/services/capabilities.js`
  def self.mobile_device?(user_agent)
    user_agent =~ /Mobile/ && !(user_agent =~ /iPad/)
  end

  MODERN_MOBILE_REGEX =
    %r{
    \(.*iPhone\ OS\ 1[6-9].*\)|
    \(.*iPad.*OS\ 1[6-9].*\)|
    Chrome\/8[89]|
    Chrome\/9[0-9]|
    Chrome\/1[0-9][0-9]|
    Firefox\/8[5-9]|
    Firefox\/9[0-9]|
    Firefox\/1[0-9][0-9]
  }x

  USER_AGENT_MAX_LENGTH = 400

  def self.modern_mobile_device?(user_agent)
    user_agent[0...USER_AGENT_MAX_LENGTH].match?(MODERN_MOBILE_REGEX)
  end
end
