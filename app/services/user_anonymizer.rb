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

      @user.update_attribute(:uploaded_avatar_id, nil)
      raise "Failed to change username" unless UsernameChanger.change(@user, make_anon_username)

      @user.reload
      @user.password = SecureRandom.hex
      @user.email = "#{@user.username}@example.com"
      @user.name = SiteSetting.full_name_required ? @user.username : nil
      @user.date_of_birth = nil
      @user.title = nil

      anonymize_ips(@opts[:anonymize_ip]) if @opts.has_key?(:anonymize_ip)

      @user.save

      options = @user.user_option
      options.email_always = false
      options.mailing_list_mode = false
      options.email_digests = false
      options.email_private_messages = false
      options.email_direct = false
      options.save

      profile = @user.user_profile
      profile.destroy if profile
      @user.create_user_profile

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

      history_details = {
        action: UserHistory.actions[:anonymize_user],
        target_user_id: @user.id,
        acting_user_id: @actor ? @actor.id : @user.id,
      }

      if SiteSetting.log_anonymizer_details?
        history_details[:email] = @prev_email
        history_details[:details] = "username: #{@prev_username}"
      end

      @user_history = UserHistory.create(history_details)
    end

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

  def ip_where(column = 'user_id')
    ["#{column} = :user_id AND ip_address IS NOT NULL", user_id: @user.id]
  end

  def anonymize_ips(new_ip)
    @user.ip_address = new_ip
    @user.registration_ip_address = new_ip

    IncomingLink.where(ip_where('current_user_id')).update_all(ip_address: new_ip)
    ScreenedEmail.where(email: @prev_email).update_all(ip_address: new_ip)
    SearchLog.where(ip_where).update_all(ip_address: new_ip)
    TopicLinkClick.where(ip_where).update_all(ip_address: new_ip)
    TopicViewItem.where(ip_where).update_all(ip_address: new_ip)
    UserHistory.where(ip_where('acting_user_id')).update_all(ip_address: new_ip)
    UserProfileView.where(ip_where).update_all(ip_address: new_ip)

    # UserHistory for delete_user logs the user's IP. Note this is quite ugly but we don't
    # have a better way of querying on details right now.
    UserHistory.where(
      "action = :action AND details LIKE 'id: #{@user.id}\n%'",
      action: UserHistory.actions[:delete_user]
    ).update_all(ip_address: new_ip)

  end

end
