require_dependency 'user'
require 'net/http'

class AvatarDetector

  def initialize(user)
    raise "Tried to detect an avatar on a non-user instance" unless user && user.is_a?(User)

    @user = user
  end

  def has_custom_avatar?
    return true if @user.uploaded_avatar_path
    has_custom_gravatar?
  end

  # Check whether the user has a gravatar by performing a HTTP HEAD request to
  # Gravatar using the `d=404` parameter.
  def has_custom_gravatar?
    result = Net::HTTP.start('www.gravatar.com') do |http|
      http.open_timeout = 2
      http.read_timeout = 2
      http.head("/avatar/#{User.email_hash(@user.email)}?d=404")
    end

    return result.code.to_i == 200
  rescue
    # If the HTTP request fails, assume no gravatar
    false
  end

end
