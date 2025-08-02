# frozen_string_literal: true

module MobileDetection
  def self.mobile_device?(user_agent)
    user_agent =~ /Mobile/ && !(user_agent =~ /iPad/)
  end

  # we need this as a reusable chunk that is called from the cache
  def self.resolve_mobile_view!(user_agent, params, session)
    return false unless SiteSetting.enable_mobile_theme

    session[:mobile_view] = params[:mobile_view] if params && params.has_key?(:mobile_view)
    session[:mobile_view] = nil if params && params.has_key?(:mobile_view) &&
      params[:mobile_view] == "auto"

    if session && session[:mobile_view]
      session[:mobile_view] == "1"
    else
      mobile_device?(user_agent)
    end
  end

  MODERN_MOBILE_REGEX =
    %r{
    \(.*iPhone\ OS\ 1[5-9].*\)|
    \(.*iPad.*OS\ 1[5-9].*\)|
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
