class UserAnonymizer

  attr_reader :user_history

  # opts:
  #   anonymize_ip  - an optional new IP to update their logs with
  def initialize(user, actor = nil, opts = nil)
    @user = user
    @actor = actor
    @user_history = nil
    @opts = opts || {}
  end

  def self.make_anonymous(user, actor = nil, opts = nil)
    self.new(user, actor, opts).make_anonymous
  end

  def make_anonymous
    User.transaction do
      @prev_email = @user.email
      @prev_username = @user.username

      unless UsernameChanger.new(@user, make_anon_username).change(run_update_job: false)
        raise "Failed to change username"
      end

      @user.reload
      @user.password = SecureRandom.hex
      @user.email = "#{@user.username}@anonymized.invalid"
      @user.name = SiteSetting.full_name_required ? @user.username : nil
      @user.date_of_birth = nil
      @user.title = nil
      @user.uploaded_avatar_id = nil

      if @opts.has_key?(:anonymize_ip)
        @user.ip_address = @opts[:anonymize_ip]
        @user.registration_ip_address = @opts[:anonymize_ip]
      end

      @user.save

      options = @user.user_option
      options.email_always = false
      options.mailing_list_mode = false
      options.email_digests = false
      options.email_private_messages = false
      options.email_direct = false
      options.save

      if profile = @user.user_profile
        profile.update(location: nil, website: nil, bio_raw: nil, bio_cooked: nil,
                       profile_background: nil, card_background: nil)
      end

      @user.user_avatar.try(:destroy)
      @user.twitter_user_info.try(:destroy)
      @user.google_user_info.try(:destroy)
      @user.github_user_info.try(:destroy)
      @user.facebook_user_info.try(:destroy)
      @user.single_sign_on_record.try(:destroy)
      @user.oauth2_user_info.try(:destroy)
      @user.instagram_user_info.try(:destroy)
      @user.user_open_ids.find_each { |x| x.destroy }
      @user.api_key.try(:destroy)

      @user_history = log_action
    end

    UsernameChanger.update_username(user_id: @user.id,
                                    old_username: @prev_username,
                                    new_username: @user.username,
                                    avatar_template: @user.avatar_template)

    Jobs.enqueue(:anonymize_user,
                 user_id: @user.id,
                 prev_email: @prev_email,
                 anonymize_ip: @opts[:anonymize_ip])

    DiscourseEvent.trigger(:user_anonymized, user: @user, opts: @opts)
    @user
  end

  private

  def make_anon_username
    100.times do
      new_username = "anon#{(SecureRandom.random_number * 100000000).to_i}"
      return new_username unless User.where(username_lower: new_username).exists?
    end
    raise "Failed to generate an anon username"
  end

  def log_action
    history_details = {
      action: UserHistory.actions[:anonymize_user],
      target_user_id: @user.id,
      acting_user_id: @actor ? @actor.id : @user.id,
    }

    if SiteSetting.log_anonymizer_details?
      history_details[:email] = @prev_email
      history_details[:details] = "username: #{@prev_username}"
    end

    UserHistory.create(history_details)
  end
end
