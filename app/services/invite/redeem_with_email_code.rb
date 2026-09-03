# frozen_string_literal: true

class Invite::RedeemWithEmailCode
  include Service::Base

  params base_class: EmailLoginCode::Verify::Contract do
    attribute :invite_key, :string
    attribute :user_fields
    attribute :name, :string

    before_validation do
      self.invite_key = invite_key.to_s.strip
      self.user_fields =
        if user_fields.is_a?(Hash) || user_fields.is_a?(ActionController::Parameters)
          user_fields.to_h.stringify_keys
        else
          {}
        end
      self.name = name.to_s.strip.presence
    end

    validates :invite_key, presence: true
    validates :name, length: { maximum: 255 }
  end

  model :invite
  policy :email_can_redeem_invite
  model :login_code
  policy :code_matches
  model :existing_user, optional: true
  policy :email_available_for_new_account
  policy :can_register_new_account
  policy :required_fields_provided
  policy :required_full_name_provided

  try(
    ActiveRecord::RecordInvalid,
    ActiveRecord::RecordNotSaved,
    ActiveRecord::LockWaitTimeout,
    Invite::UserExists,
  ) do
    lock(:email) do
      transaction do
        step :consume_code
        model :user, :redeem_invite
      end
    end
  end

  only_if(:welcome_message_pending?) { step :send_welcome_message }
  only_if(:staff_user?) { step :refresh_automatic_groups }
  step :create_topic_notifications

  private

  def fetch_invite(params:)
    invite = Invite.find_by(invite_key: params.invite_key)
    invite if invite&.redeemable?
  end

  def email_can_redeem_invite(invite:, params:)
    return if invite.email.present? && !invite.email_matches?(params.email)
    return if invite.domain.present? && !invite.domain_matches?(params.email)

    true
  end

  def fetch_login_code(params:)
    EmailLoginCode.active.for_email(params.email).first
  end

  def code_matches(login_code:, params:)
    login_code.verify(params.code)
  end

  def fetch_existing_user(params:)
    User.real.where(staged: false).with_email(params.email).first
  end

  def email_available_for_new_account(existing_user:, params:)
    return true if existing_user.present?

    User::Action::FindByEmail.call(email: params.email).blank?
  end

  def can_register_new_account(existing_user:, params:)
    return true if existing_user.present?

    SiteSetting.allow_new_registrations && EmailValidator.allowed?(params.email) &&
      !ScreenedEmail.should_block?(params.email)
  end

  def required_fields_provided(existing_user:, params:)
    return true if existing_user.present?

    UserField
      .required
      .where(show_on_signup: true)
      .pluck(:id)
      .all? do |field_id|
        value = params.user_fields[field_id.to_s]
        value.present? && value != "false"
      end
  end

  def required_full_name_provided(existing_user:, params:)
    return true if existing_user.present?

    !Site.full_name_required_for_signup || params.name.present?
  end

  def consume_code(login_code:)
    fail!("code already redeemed") unless login_code.consume!
  end

  def redeem_invite(existing_user:, invite:, params:, ip_address:)
    attributes =
      if existing_user
        { redeeming_user: existing_user }
      else
        {
          email: params.email,
          name: params.name,
          user_custom_fields: params.user_fields,
          ip_address: ip_address,
          email_verified: true,
        }
      end

    invite.redeem(**attributes)
  end

  def welcome_message_pending?(user:)
    user.send_welcome_message
  end

  def send_welcome_message(user:)
    user.enqueue_welcome_message("welcome_invite")
  end

  def staff_user?(user:)
    user.staff?
  end

  def refresh_automatic_groups
    Group.refresh_automatic_groups!(:admins, :moderators, :staff)
  end

  def create_topic_notifications(invite:, user:)
    invite.topics.each do |topic|
      next if !user.guardian.can_see?(topic)

      recent_notification =
        user
          .notifications
          .where(notification_type: Notification.types[:invited_to_topic])
          .where(topic_id: topic.id, post_number: 1)
          .where("created_at > ?", 1.hour.ago)
      next if recent_notification.exists?

      topic.create_invite_notification!(
        user,
        Notification.types[:invited_to_topic],
        invite.invited_by,
      )
    end
  end
end
