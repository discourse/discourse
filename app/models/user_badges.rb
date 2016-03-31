# view model for user badges
class UserBadges
  alias :read_attribute_for_serialization :send

  attr_accessor :user_badges, :username, :grant_count

  def initialize(opts={})
    @user_badges = opts[:user_badges]
    @username = opts[:username]
    @grant_count = opts[:grant_count]
  end
end
