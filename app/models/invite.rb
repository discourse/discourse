# frozen_string_literal: true

class Invite < ActiveRecord::Base
  class UserExists < StandardError; end
  class RedemptionFailed < StandardError; end
  class ValidationFailed < StandardError; end

  include RateLimiter::OnCreateRecord
  include Trashable

  # TODO(2021-05-22): remove
  self.ignored_columns = %w{
    user_id
    redeemed_at
  }

  BULK_INVITE_EMAIL_LIMIT = 200
  DOMAIN_REGEX = /\A(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])\z/

  rate_limit :limit_invites_per_day

  belongs_to :invited_by, class_name: 'User'

  has_many :invited_users
  has_many :users, through: :invited_users
  has_many :invited_groups
  has_many :groups, through: :invited_groups
  has_many :topic_invites
  has_many :topics, through: :topic_invites, source: :topic

  validates_presence_of :invited_by_id
  validates :email, email: true, allow_blank: true
  validate :ensure_max_redemptions_allowed
  validate :valid_domain, if: :will_save_change_to_domain?
  validate :user_doesnt_already_exist, if: :will_save_change_to_email?

  before_create do
    self.invite_key ||= SecureRandom.base58(10)
    self.expires_at ||= SiteSetting.invite_expiry_days.days.from_now
  end

  before_save do
    if will_save_change_to_email?
      self.email_token = email.present? ? SecureRandom.hex : nil
    end
  end

  before_validation do
    self.email = Email.downcase(email) unless email.nil?
  end

  attr_accessor :email_already_exists

  def self.emailed_status_types
    @emailed_status_types ||= Enum.new(not_required: 0, pending: 1, bulk_pending: 2, sending: 3, sent: 4)
  end

  def user_doesnt_already_exist
    @email_already_exists = false
    return if email.blank?
    user = Invite.find_user_by_email(email)

    if user && user.id != self.invited_users&.first&.user_id
      @email_already_exists = true
      errors.add(:base, user_exists_error_msg(email, user.username))
    end
  end

  def is_invite_link?
    email.blank?
  end

  def redeemable?
    !redeemed? && !expired? && !deleted_at? && !destroyed? && link_valid?
  end

  def redeemed?
    if is_invite_link?
      redemption_count >= max_redemptions_allowed
    else
      self.invited_users.count > 0
    end
  end

  def expired?
    expires_at < Time.zone.now
  end

  def link(with_email_token: false)
    with_email_token ? "#{Discourse.base_url}/invites/#{invite_key}?t=#{email_token}"
                     : "#{Discourse.base_url}/invites/#{invite_key}"
  end

  def link_valid?
    invalidated_at.nil?
  end

  def self.generate(invited_by, opts = nil)
    opts ||= {}

    email = Email.downcase(opts[:email]) if opts[:email].present?

    if user = find_user_by_email(email)
      raise UserExists.new(new.user_exists_error_msg(email, user.username))
    end

    if email.present?
      invite = Invite
        .with_deleted
        .where(email: email, invited_by_id: invited_by.id)
        .order('created_at DESC')
        .first

      if invite && (invite.expired? || invite.deleted_at)
        invite.destroy
        invite = nil
      end
    end

    emailed_status = if opts[:skip_email] || invite&.emailed_status == emailed_status_types[:not_required]
      emailed_status_types[:not_required]
    elsif opts[:emailed_status].present?
      opts[:emailed_status]
    elsif email.present?
      emailed_status_types[:pending]
    else
      emailed_status_types[:not_required]
    end

    if invite
      invite.update_columns(
        created_at: Time.zone.now,
        updated_at: Time.zone.now,
        expires_at: opts[:expires_at] || SiteSetting.invite_expiry_days.days.from_now,
        emailed_status: emailed_status
      )
    else
      create_args = opts.slice(:email, :domain, :moderator, :custom_message, :max_redemptions_allowed)
      create_args[:invited_by] = invited_by
      create_args[:email] = email
      create_args[:emailed_status] = emailed_status
      create_args[:expires_at] = opts[:expires_at] || SiteSetting.invite_expiry_days.days.from_now

      invite = Invite.create!(create_args)
    end

    topic_id = opts[:topic]&.id || opts[:topic_id]
    if topic_id.present?
      invite.topic_invites.find_or_create_by!(topic_id: topic_id)
    end

    group_ids = opts[:group_ids]
    if group_ids.present?
      group_ids.each do |group_id|
        invite.invited_groups.find_or_create_by!(group_id: group_id)
      end
    end

    if emailed_status == emailed_status_types[:pending]
      invite.update_column(:emailed_status, emailed_status_types[:sending])
      Jobs.enqueue(:invite_email, invite_id: invite.id, invite_to_topic: opts[:invite_to_topic])
    end

    invite.reload
  end

  def redeem(email: nil, username: nil, name: nil, password: nil, user_custom_fields: nil, ip_address: nil, session: nil, email_token: nil)
    return if !redeemable?

    if is_invite_link? && UserEmail.exists?(email: email)
      raise UserExists.new I18n.t("invite_link.email_taken")
    end

    email = self.email if email.blank? && !is_invite_link?
    InviteRedeemer.new(
      invite: self,
      email: email,
      username: username,
      name: name,
      password: password,
      user_custom_fields: user_custom_fields,
      ip_address: ip_address,
      session: session,
      email_token: email_token
    ).redeem
  end

  def self.redeem_from_email(email)
    invite = Invite.find_by(email: Email.downcase(email))
    InviteRedeemer.new(invite: invite, email: invite.email).redeem if invite
    invite
  end

  def self.find_user_by_email(email)
    User.with_email(Email.downcase(email)).where(staged: false).first
  end

  def self.pending(inviter)
    Invite.distinct
      .joins("LEFT JOIN invited_users ON invites.id = invited_users.invite_id")
      .joins("LEFT JOIN users ON invited_users.user_id = users.id")
      .where(invited_by_id: inviter.id)
      .where('redemption_count < max_redemptions_allowed')
      .where('expires_at > ?', Time.zone.now)
      .order('invites.updated_at DESC')
  end

  def self.expired(inviter)
    Invite.distinct
      .joins("LEFT JOIN invited_users ON invites.id = invited_users.invite_id")
      .joins("LEFT JOIN users ON invited_users.user_id = users.id")
      .where(invited_by_id: inviter.id)
      .where('redemption_count < max_redemptions_allowed')
      .where('expires_at < ?', Time.zone.now)
      .order('invites.expires_at ASC')
  end

  def self.redeemed_users(inviter)
    InvitedUser
      .joins("LEFT JOIN invites ON invites.id = invited_users.invite_id")
      .includes(user: :user_stat)
      .where('invited_users.user_id IS NOT NULL')
      .where('invites.invited_by_id = ?', inviter.id)
      .order('invited_users.redeemed_at DESC')
      .references('invite')
      .references('user')
      .references('user_stat')
  end

  def self.invalidate_for_email(email)
    invite = Invite.find_by(email: Email.downcase(email))
    invite.update!(invalidated_at: Time.zone.now) if invite

    invite
  end

  def resend_invite
    self.update_columns(updated_at: Time.zone.now, invalidated_at: nil, expires_at: SiteSetting.invite_expiry_days.days.from_now)
    Jobs.enqueue(:invite_email, invite_id: self.id)
  end

  def warnings(guardian)
    @warnings ||= begin
      warnings = []

      topic = self.topics.first
      if topic&.read_restricted_category?
        topic_groups = topic.category.groups
        if (self.groups & topic_groups).blank?
          editable_topic_groups = topic_groups.filter { |g| guardian.can_edit_group?(g) }
          warnings << I18n.t("invite.requires_groups", groups: editable_topic_groups.pluck(:name).join(", "))
        end
      end

      warnings
    end
  end

  def limit_invites_per_day
    RateLimiter.new(invited_by, "invites-per-day", SiteSetting.max_invites_per_day, 1.day.to_i)
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv", RailsMultisite::ConnectionManagement.current_db)
  end

  def ensure_max_redemptions_allowed
    if self.max_redemptions_allowed.nil?
      self.max_redemptions_allowed = 1
    else
      limit = invited_by&.staff? ? SiteSetting.invite_link_max_redemptions_limit
                                 : SiteSetting.invite_link_max_redemptions_limit_users

      if !self.max_redemptions_allowed.between?(1, limit)
        errors.add(:max_redemptions_allowed, I18n.t("invite_link.max_redemptions_limit", max_limit: limit))
      end
    end
  end

  def valid_domain
    return if self.domain.blank?

    self.domain.downcase!

    if self.domain !~ Invite::DOMAIN_REGEX
      self.errors.add(:base, I18n.t('invite.domain_not_allowed'))
    end
  end

  def user_exists_error_msg(email, username)
    sanitized_email = CGI.escapeHTML(email)
    sanitized_username = CGI.escapeHTML(username)

    I18n.t(
      "invite.user_exists",
      email: sanitized_email, username: sanitized_username, base_path: Discourse.base_path
    )
  end
end

# == Schema Information
#
# Table name: invites
#
#  id                      :integer          not null, primary key
#  invite_key              :string(32)       not null
#  email                   :string
#  invited_by_id           :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  deleted_at              :datetime
#  deleted_by_id           :integer
#  invalidated_at          :datetime
#  moderator               :boolean          default(FALSE), not null
#  custom_message          :text
#  emailed_status          :integer
#  max_redemptions_allowed :integer          default(1), not null
#  redemption_count        :integer          default(0), not null
#  expires_at              :datetime         not null
#  email_token             :string
#  domain                  :string
#
# Indexes
#
#  index_invites_on_email_and_invited_by_id  (email,invited_by_id)
#  index_invites_on_emailed_status           (emailed_status)
#  index_invites_on_invite_key               (invite_key) UNIQUE
#  index_invites_on_invited_by_id            (invited_by_id)
#
