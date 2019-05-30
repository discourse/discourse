# frozen_string_literal: true

module MobileDetection
  def self.mobile_device?(user_agent)
    user_agent =~ /Mobile/ && !(user_agent =~ /iPad/)
  end

  # we need this as a reusable chunk that is called from the cache
  def self.resolve_mobile_view!(user_agent, params, session)
    return false unless SiteSetting.enable_mobile_theme

    session[:mobile_view] = params[:mobile_view] if params && params.has_key?(:mobile_view)
    session[:mobile_view] = nil if params && params.has_key?(:mobile_view) && params[:mobile_view] == 'auto'

    if session && session[:mobile_view]
      session[:mobile_view] == '1'
    else
      mobile_device?(user_agent)
    end
  end

  def self.ios_device?(user_agent)
    user_agent =~ /iPad|iPhone|iPod/
  end

end
