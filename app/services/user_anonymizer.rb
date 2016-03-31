class UserAnonymizer
  def initialize(user, actor=nil)
    @user = user
    @actor = actor
  end

  def self.make_anonymous(user, actor=nil)
    self.new(user, actor).make_anonymous
  end

  def make_anonymous
    User.transaction do
      prev_email = @user.email
      prev_username = @user.username

      if !UsernameChanger.change(@user, make_anon_username)
        raise "Failed to change username"
      end

      @user.reload
      @user.password = SecureRandom.hex
      @user.email = "#{@user.username}@example.com"
      @user.name = SiteSetting.full_name_required ? @user.username : nil
      @user.date_of_birth = nil
      @user.title = nil
      @user.uploaded_avatar_id = nil
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
      @user.user_open_ids.find_each { |x| x.destroy }
      @user.api_key.try(:destroy)

      UserHistory.create( action: UserHistory.actions[:anonymize_user],
                          target_user_id: @user.id,
                          acting_user_id: @actor ? @actor.id : @user.id,
                          email: prev_email,
                          details: "username: #{prev_username}" )
    end
    @user
  end

  def make_anon_username
    100.times do
      new_username = "anon#{(SecureRandom.random_number * 100000000).to_i}"
      return new_username unless User.where(username_lower: new_username).exists?
    end
    raise "Failed to generate an anon username"
  end
end
