# frozen_string_literal: true

class UserCreator
  class UploadNotFound < StandardError
  end

  def self.create(guardian, attributes)
    new(guardian, attributes).create
  end

  def self.registration_error(invite_code: nil)
    return "login.new_registrations_disabled" unless SiteSetting.allow_new_registrations
    if SiteSetting.require_invite_code &&
         SiteSetting.invite_code.strip.downcase != invite_code.to_s.strip.downcase
      "login.wrong_invite_code"
    end
  end

  def self.assign_signup_fields(user)
    fields = user.custom_fields
    UserField.all.each do |field|
      value = yield(field)
      value = nil if value == "false"
      if value.blank?
        return "login.missing_user_field" if field.required?
      else
        fields["#{User::USER_FIELD_PREFIX}#{field.id}"] = value[0...UserField.max_length]
      end
    end
    user.custom_fields = fields
    nil
  end

  def initialize(guardian, attributes)
    @guardian = guardian
    @attributes = attributes.to_h.with_indifferent_access
  end

  def create
    raise Discourse::InvalidAccess if !guardian.is_admin?

    user = User.new
    error = self.class.registration_error || self.class.assign_signup_fields(user) { nil }
    if error
      user.errors.add(:base, I18n.t(error))
      return user
    end

    if attributes[:password].blank?
      user.errors.add(:password, :blank)
      return user
    end

    upload = find_upload
    user = nil
    User.transaction do
      user =
        User::Action::CreateFromVerifiedEmail.call(
          email: Email.downcase(attributes[:email]),
          username: attributes[:username],
          name: attributes[:name],
          password: attributes[:password],
        )
      raise ActiveRecord::Rollback if !user.persisted? || user.errors.present?

      if attributes.fetch(:approved, true)
        approve(user)
      else
        user.update!(approved: false, approved_by_id: nil, approved_at: nil)
      end
      if attributes.fetch(:active, true)
        activate(user)
      else
        send_activation_email(user)
      end
      update_avatar(user, upload) if upload
      log_creation(user)
    end
    user
  end

  private

  attr_reader :guardian, :attributes

  def find_upload
    return if attributes[:upload_id].blank?

    Upload.find_by(id: attributes[:upload_id]) || raise(UploadNotFound)
  end

  def approve(user)
    return if user.approved?

    ReviewableUser.set_approved_fields!(user, guardian.user)
    user.save!
  end

  def activate(user)
    user.activate
    user.enqueue_welcome_message("welcome_user") if user.guardian.can_access_forum?
  end

  def send_activation_email(user)
    email_token = user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:signup])
    EmailToken.enqueue_signup_email(email_token)
  end

  def update_avatar(user, upload)
    user = User.find(user.id)
    Group.refresh_automatic_groups_for_user!(user)
    UserAvatarUpdater.update(guardian, user, upload)
  end

  def log_creation(user)
    StaffActionLogger.new(guardian.user).log_custom(
      "create_user",
      target_user_id: user.id,
      subject: user.username,
      active: user.active?,
      approved: user.approved?,
    )
  end
end
