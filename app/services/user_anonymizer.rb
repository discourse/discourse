# frozen_string_literal: true

class UserAnonymizer
  attr_reader :user_history

  EMAIL_SUFFIX = "@anonymized.invalid"

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
      @user.name = SiteSetting.full_name_required ? @user.username : nil
      @user.date_of_birth = nil
      @user.title = nil
      @user.uploaded_avatar_id = nil

      if @opts.has_key?(:anonymize_ip)
        @user.ip_address = @opts[:anonymize_ip]
        @user.registration_ip_address = @opts[:anonymize_ip]
      end

      @user.save!

      @user.primary_email.update_attribute(:email, "#{@user.username}#{EMAIL_SUFFIX}")
      @user.primary_email.update_attribute(:normalized_email, "#{@user.username}#{EMAIL_SUFFIX}")

      options = @user.user_option
      options.mailing_list_mode = false
      options.email_digests = false
      options.email_level = UserOption.email_level_types[:never]
      options.email_messages_level = UserOption.email_level_types[:never]
      options.save!

      if profile = @user.user_profile
        profile.update!(
          location: nil,
          website: nil,
          bio_raw: nil,
          bio_cooked: nil,
          profile_background_upload: nil,
          card_background_upload: nil,
        )
      end

      @user.clear_status!

      @user.user_avatar&.destroy!
      @user.single_sign_on_record&.destroy!
      @user.oauth2_user_infos.destroy_all
      @user.user_associated_accounts.destroy_all
      @user.api_keys.destroy_all
      @user.user_api_keys.destroy_all
      @user.user_emails.secondary.destroy_all

      @user_history = log_action
    end

    UsernameChanger.update_username(
      user_id: @user.id,
      old_username: @prev_username,
      new_username: @user.username,
      avatar_template: @user.avatar_template,
    )

    Jobs.enqueue(
      :anonymize_user,
      user_id: @user.id,
      prev_email: @prev_email,
      anonymize_ip: @opts[:anonymize_ip],
    )

    DiscourseEvent.trigger(:user_anonymized, user: @user, opts: @opts)
    @user
  end

  private

  def make_anon_username
    100.times do
      new_username = "anon#{(SecureRandom.random_number * 100_000_000).to_i}"
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

    UserHistory.create!(history_details)
  end
end
