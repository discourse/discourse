# frozen_string_literal: true

module MobileDetection
  # if the criteria for mobile_device? changes, update the code for `isMobileDevice` in
  # `frontend/discourse/app/services/capabilities.js`
  def self.mobile_device?(user_agent)
    return false if !user_agent
    user_agent.include?("Mobile") && !user_agent.include?("iPad")
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
    user_agent = user_agent[0...USER_AGENT_MAX_LENGTH] if user_agent.length > USER_AGENT_MAX_LENGTH
    MODERN_MOBILE_REGEX.match?(user_agent)
  end
end
