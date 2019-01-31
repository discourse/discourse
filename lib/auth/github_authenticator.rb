require_dependency 'has_errors'

class Auth::GithubAuthenticator < Auth::Authenticator

  def name
    "github"
  end

  def enabled?
    SiteSetting.enable_github_logins
  end

  def description_for_user(user)
    info = GithubUserInfo.find_by(user_id: user.id)
    info&.screen_name || ""
  end

  def can_revoke?
    true
  end

  def revoke(user, skip_remote: false)
    info = GithubUserInfo.find_by(user_id: user.id)
    raise Discourse::NotFound if info.nil?
    info.destroy!
    true
  end

  class GithubEmailChecker
    include ::HasErrors

    def initialize(validator, email)
      @validator = validator
      @email = Email.downcase(email)
    end

    def valid?()
      @validator.validate_each(self, :email, @email)
      return errors.blank?
    end

  end

  def can_connect_existing_user?
    true
  end

  def after_authenticate(auth_token, existing_account: nil)
    result = Auth::Result.new

    data = auth_token[:info]
    result.username = screen_name = data[:nickname]
    result.name = data[:name]

    github_user_id = auth_token[:uid]

    result.extra_data = {
      github_user_id: github_user_id,
      github_screen_name: screen_name,
    }

    user_info = GithubUserInfo.find_by(github_user_id: github_user_id)

    if existing_account && (user_info.nil? || existing_account.id != user_info.user_id)
      user_info.destroy! if user_info
      user_info = GithubUserInfo.create(
        user_id: existing_account.id,
        screen_name: screen_name,
        github_user_id: github_user_id
        )
    end

    if user_info
      # If there's existing user info with the given GitHub ID, that's all we
      # need to know.
      user = user_info.user
      result.email = data[:email]
      result.email_valid = data[:email].present?
    else
      # Potentially use *any* of the emails from GitHub to find a match or
      # register a new user, with preference given to the primary email.
      all_emails = Array.new(auth_token[:extra][:all_emails])
      primary = all_emails.detect { |email| email[:primary] && email[:verified] }
      all_emails.unshift(primary) if primary.present?

      # Only consider verified emails to match an existing user.  We don't want
      # someone to be able to create a GitHub account with an unverified email
      # in order to access someone else's Discourse account!
      all_emails.each do |candidate|
        if !!candidate[:verified] && (user = User.find_by_email(candidate[:email]))
          result.email = candidate[:email]
          result.email_valid = !!candidate[:verified]

          GithubUserInfo
            .where('user_id = ? OR github_user_id = ?', user.id, github_user_id)
            .destroy_all

          GithubUserInfo.create!(
              user_id: user.id,
              screen_name: screen_name,
              github_user_id: github_user_id
          )
          break
        end
      end

      # If we *still* don't have a user, check to see if there's an email that
      # passes validation (this includes whitelist/blacklist filtering if any is
      # configured).  When no whitelist/blacklist is in play, this will simply
      # choose the primary email since it's at the front of the list.
      if !user
        validator = EmailValidator.new(attributes: :email)
        found_email = false
        all_emails.each do |candidate|
          checker = GithubEmailChecker.new(validator, candidate[:email])
          if checker.valid?
            result.email = candidate[:email]
            result.email_valid = !!candidate[:verified]
            found_email = true
            break
          end
        end

        if !found_email
          result.failed = true
          escaped = Rack::Utils.escape_html(screen_name)
          result.failed_reason = I18n.t("login.authenticator_error_no_valid_email", account: escaped)
        end
      end
    end

    retrieve_avatar(user, data)

    result.user = user
    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    GithubUserInfo.create(
      user_id: user.id,
      screen_name: data[:github_screen_name],
      github_user_id: data[:github_user_id]
    )

    retrieve_avatar(user, data)
  end

  def register_middleware(omniauth)
    omniauth.provider :github,
           setup: lambda { |env|
             strategy = env["omniauth.strategy"]
              strategy.options[:client_id] = SiteSetting.github_client_id
              strategy.options[:client_secret] = SiteSetting.github_client_secret
           },
           scope: "user:email"
  end

  private

  def retrieve_avatar(user, data)
    return unless data[:image].present? && user && user.user_avatar&.custom_upload_id.blank?

    Jobs.enqueue(:download_avatar_from_url, url: data[:image], user_id: user.id, override_gravatar: false)
  end
end
