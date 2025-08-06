# frozen_string_literal: true

# name: discourse-lti
# about: Allows login integration with a number of learning management systems via the LTI 1.3 standard.
# meta_topic_id: 196174
# version: 1.0
# authors: David Taylor
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-lti

enabled_site_setting :lti_enabled

module ::DiscourseLti
  PLUGIN_NAME = "discourse-lti"
  CUSTOM_DATA_CLAIM = "https://purl.imsglobal.org/spec/lti/claim/custom"
  DISCOURSE_INVITE_KEYS = %w[discourse_invite_link custom_discourse_invite_link] # Coursera prefixes keys with `custom_`

  class ShouldReconnect < StandardError
  end
end

after_initialize do
  # Check for invite URL in LTI custom fields
  # If present, and this is a new user, redirect the user to the invite url.
  # Otherwise, continue as normal
  on(:after_auth) do |authenticator, auth_result, session|
    next if !(authenticator.name.to_sym == :lti)
    next if auth_result.user # Only redirect new users to invite

    uaa =
      UserAssociatedAccount.find_by(
        provider_name: "lti",
        provider_uid: auth_result.extra_data[:uid],
      )
    next if uaa.nil?

    custom_data = uaa.extra.dig("raw_info", ::DiscourseLti::CUSTOM_DATA_CLAIM)
    next if custom_data.nil?

    invite = nil
    ::DiscourseLti::DISCOURSE_INVITE_KEYS.each { |k| break if invite = custom_data[k] }
    next if invite.nil?

    parsed =
      begin
        URI.parse(invite)
      rescue URI::Error
        next
      end
    next if parsed.nil?
    next if parsed.host && parsed.host != Discourse.current_hostname

    route = Discourse.route_for(parsed.path)
    next if !(route[:controller] == "invites" && route[:action] == "show")

    session[:destination_url] = parsed.to_s
  end

  on(:after_auth) do |authenticator, auth_result, session, cookies|
    next if !(authenticator.name.to_sym == :lti)
    if !auth_result.user && cookies["_t"] # User (probably) already logged in
      raise ::DiscourseLti::ShouldReconnect.new
    end
  end

  reloadable_patch do
    ::Users::OmniauthCallbacksController.rescue_from(::DiscourseLti::ShouldReconnect) do
      session[:auth_reconnect] = true
      complete
    end
  end
end

require_relative "lib/discourse_lti/lti_omniauth_strategy"
require_relative "lib/discourse_lti/lti_authenticator"

auth_provider authenticator: ::DiscourseLti::LtiAuthenticator.new
