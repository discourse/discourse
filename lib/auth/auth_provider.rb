# frozen_string_literal: true

class Auth::AuthProvider
  include ActiveModel::Serialization

  def initialize(params = {})
    params.each { |key, value| public_send "#{key}=", value }
  end

  def self.auth_attributes
    %i[
      authenticator
      pretty_name
      title
      frame_width
      frame_height
      pretty_name_setting
      title_setting
      custom_url
      icon
    ]
  end

  attr_accessor(*auth_attributes)

  def name
    authenticator.name
  end

  def can_connect
    authenticator.can_connect_existing_user?
  end

  def can_revoke
    authenticator.can_revoke?
  end
end
