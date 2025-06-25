# frozen_string_literal: true

class Auth::AuthProvider
  include ActiveModel::Serialization

  def initialize(params = {})
    params.each { |key, value| public_send "#{key}=", value }
  end

  def self.auth_attributes
    %i[
      authenticator
      custom_url
      frame_height
      frame_width
      icon
      pretty_name
      pretty_name_setting
      title
      title_setting
    ]
  end

  attr_accessor(*auth_attributes)

  def can_connect
    authenticator.can_connect_existing_user?
  end

  def can_revoke
    authenticator.can_revoke?
  end

  def name
    authenticator.name
  end

  def provider_url
    authenticator.provider_url
  end
end
