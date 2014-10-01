class UserAssociatedAccounts
  extend Forwardable

  def_delegators :user, :twitter_user_info, :facebook_user_info, :google_user_info, :github_user_info, :user_open_ids

  attr_reader :user
  attr_accessor :accounts
  
  def initialize(user)
    @user = user
    @accounts = []
  end

  def associated_accounts
    unless accounts.present?
      twitter_screen_name
      facebook_username
      google_email
      github_screen_name
      user_open_ids_info
    end
    accounts.empty? ? I18n.t("user.no_accounts_associated") : accounts.join(", ")
  end

  private

  def twitter_screen_name
    accounts << "Twitter(#{twitter_user_info.screen_name})" if twitter_user_info
  end

  def facebook_username
    accounts << "Facebook(#{facebook_user_info.username})" if facebook_user_info
  end

  def google_email
    accounts << "Google(#{google_user_info.email})" if google_user_info
  end

  def github_screen_name
    accounts << "Github(#{github_user_info.screen_name})" if github_user_info
  end

  def user_open_ids_info
    user_open_ids.each do |oid|
      result << "OpenID #{oid.url[0..20]}...(#{oid.email})"
    end
  end
end
