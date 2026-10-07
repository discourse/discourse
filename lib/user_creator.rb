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
        if field.required?
          user.errors.add(
            :base,
            I18n.t("login.missing_user_field_details", name: field.name, id: field.id),
          )
          return "login.missing_user_field"
        end
      else
        fields["#{User::USER_FIELD_PREFIX}#{field.id}"] = value[0...UserField.max_length]
      end
    end
    user.custom_fields = fields
    nil
  end

  def self.clean_custom_field_values(field, field_values)
    return field_values if field_values.nil? || field_values.empty?

    if field.field_type == "dropdown"
      field.user_field_options.find_by_value(field_values)&.value
    elsif field.field_type == "multiselect"
      field_values = Array.wrap(field_values)
      bad_values = field_values - field.user_field_options.map(&:value)
      field_values - bad_values
    else
      field_values
    end
  end

  def initialize(guardian, attributes)
    @guardian = guardian
    @attributes = attributes.to_h.with_indifferent_access
  end

  def create
    raise Discourse::InvalidAccess if !guardian.is_admin?

    user = User.new
    if error = self.class.registration_error(invite_code: attributes[:invite_code])
      user.errors.add(:base, I18n.t(error))
      return user
    end

    error =
      self
        .class
        .assign_signup_fields(user) do |field|
          self.class.clean_custom_field_values(field, attributes.dig(:user_fields, field.id.to_s))
        end
    return user if error
    custom_fields = user.custom_fields

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

      user.custom_fields.merge!(custom_fields)
      user.save!

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
