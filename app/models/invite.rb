# frozen_string_literal: true

class Invite < ActiveRecord::Base
  class UserExists < StandardError; end
  include RateLimiter::OnCreateRecord
  include Trashable

  # TODO(2021-05-22): remove
  self.ignored_columns = %w{
    user_id
    redeemed_at
  }

  BULK_INVITE_EMAIL_LIMIT = 200

  rate_limit :limit_invites_per_day

  belongs_to :user
  belongs_to :topic
  belongs_to :invited_by, class_name: 'User'

  has_many :invited_users
  has_many :users, through: :invited_users
  has_many :invited_groups
  has_many :groups, through: :invited_groups
  has_many :topic_invites
  has_many :topics, through: :topic_invites, source: :topic
  validates_presence_of :invited_by_id
  validates :email, email: true, allow_blank: true

  before_create do
    self.invite_key ||= SecureRandom.hex
    self.expires_at ||= SiteSetting.invite_expiry_days.days.from_now
  end

  before_validation do
    self.email = Email.downcase(email) unless email.nil?
  end

  validate :ensure_max_redemptions_allowed
  validate :user_doesnt_already_exist
  attr_accessor :email_already_exists

  scope :single_use_invites, -> { where('invites.max_redemptions_allowed = 1') }
  scope :multiple_use_invites, -> { where('invites.max_redemptions_allowed > 1') }

  def self.emailed_status_types
    @emailed_status_types ||= Enum.new(not_required: 0, pending: 1, bulk_pending: 2, sending: 3, sent: 4)
  end

  def user_doesnt_already_exist
    @email_already_exists = false
    return if email.blank?
    user = Invite.find_user_by_email(email)

    if user && user.id != self.invited_users&.first&.user_id
      @email_already_exists = true
      errors.add(:email)
    end
  end

  def is_invite_link?
    max_redemptions_allowed > 1
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

  # link_valid? indicates whether the invite link can be used to log in to the site
  def link_valid?
    invalidated_at.nil?
  end

  def redeem(username: nil, name: nil, password: nil, user_custom_fields: nil, ip_address: nil)
    if !expired? && !destroyed? && link_valid?
      InviteRedeemer.new(invite: self, email: self.email, username: username, name: name, password: password, user_custom_fields: user_custom_fields, ip_address: ip_address).redeem
    end
  end

  def self.invite_by_email(email, invited_by, topic = nil, group_ids = nil, custom_message = nil)
    create_invite_by_email(email, invited_by,
      topic: topic,
      group_ids: group_ids,
      custom_message: custom_message,
      emailed_status: emailed_status_types[:pending]
    )
  end

  def self.generate_single_use_invite_link(email, invited_by, topic = nil, group_ids = nil)
    invite = create_invite_by_email(email, invited_by,
      topic: topic,
      group_ids: group_ids,
      emailed_status: emailed_status_types[:not_required]
    )

    "#{Discourse.base_url}/invites/#{invite.invite_key}" if invite
  end

  # Create an invite for a user, supplying an optional topic
  #
  # Return the previously existing invite if already exists. Returns nil if the invite can't be created.
  def self.create_invite_by_email(email, invited_by, opts = nil)
    opts ||= {}

    topic = opts[:topic]
    group_ids = opts[:group_ids]
    custom_message = opts[:custom_message]
    emailed_status = opts[:emailed_status] || emailed_status_types[:pending]
    lower_email = Email.downcase(email)

    if user = find_user_by_email(lower_email)
      raise UserExists.new(I18n.t("invite.user_exists",
        email: lower_email,
        username: user.username,
        base_path: Discourse.base_path
      ))
    end

    invite = Invite.with_deleted
      .where(email: lower_email, invited_by_id: invited_by.id)
      .order('created_at DESC')
      .first

    if invite && (invite.expired? || invite.deleted_at)
      invite.destroy
      invite = nil
    end

    if invite
      if invite.emailed_status == Invite.emailed_status_types[:not_required]
        emailed_status = invite.emailed_status
      end

      invite.update_columns(
        created_at: Time.zone.now,
        updated_at: Time.zone.now,
        expires_at: SiteSetting.invite_expiry_days.days.from_now,
        emailed_status: emailed_status
      )
    else
      create_args = {
        invited_by: invited_by,
        email: lower_email,
        emailed_status: emailed_status
      }

      create_args[:moderator] = true if opts[:moderator]
      create_args[:custom_message] = custom_message if custom_message
      invite = Invite.create!(create_args)
    end

    if topic && !invite.topic_invites.pluck(:topic_id).include?(topic.id)
      invite.topic_invites.create!(invite_id: invite.id, topic_id: topic.id)
      # to correct association
      topic.reload
    end

    if group_ids.present?
      group_ids = group_ids - invite.invited_groups.pluck(:group_id)

      group_ids.each do |group_id|
        invite.invited_groups.create!(group_id: group_id)
      end
    end

    if emailed_status == emailed_status_types[:pending]
      invite.update_column(:emailed_status, Invite.emailed_status_types[:sending])
      Jobs.enqueue(:invite_email, invite_id: invite.id)
    end

    invite.reload
    invite
  end

  def self.generate_multiple_use_invite_link(invited_by:, max_redemptions_allowed: 5, expires_at: 1.month.from_now, group_ids: nil)
    Invite.transaction do
      create_args = {
        invited_by: invited_by,
        max_redemptions_allowed: max_redemptions_allowed.to_i,
        expires_at: expires_at,
        emailed_status: emailed_status_types[:not_required]
      }
      invite = Invite.create!(create_args)

      if group_ids.present?
        now = Time.zone.now
        invited_groups = group_ids.map { |group_id| { group_id: group_id, invite_id: invite.id, created_at: now, updated_at: now } }
        InvitedGroup.insert_all(invited_groups)
      end

      "#{Discourse.base_url}/invites/#{invite.invite_key}"
    end
  end

  # redeem multiple use invite link
  def redeem_invite_link(email: nil, username: nil, name: nil, password: nil, user_custom_fields: nil, ip_address: nil)
    DistributedMutex.synchronize("redeem_invite_link_#{self.id}") do
      reload
      if is_invite_link? && !expired? && !redeemed? && !destroyed? && link_valid?
        raise UserExists.new I18n.t("invite_link.email_taken") if UserEmail.exists?(email: email)
        InviteRedeemer.new(invite: self, email: email, username: username, name: name, password: password, user_custom_fields: user_custom_fields, ip_address: ip_address).redeem
      end
    end
  end

  def self.find_user_by_email(email)
    User.with_email(Email.downcase(email)).where(staged: false).first
  end

  def self.get_group_ids(group_names)
    group_ids = []
    if group_names
      group_names = group_names.split(',')
      group_names.each { |group_name|
        group_detail = Group.find_by_name(group_name)
        group_ids.push(group_detail.id) if group_detail
      }
    end
    group_ids
  end

  def self.find_all_pending_invites_from(inviter, offset = 0, limit = SiteSetting.invites_per_page)
    Invite.single_use_invites
      .joins("LEFT JOIN invited_users ON invites.id = invited_users.invite_id")
      .joins("LEFT JOIN users ON invited_users.user_id = users.id")
      .where('invited_users.user_id IS NULL')
      .where(invited_by_id: inviter.id)
      .where('invites.email IS NOT NULL')
      .order('invites.updated_at DESC')
      .limit(limit)
      .offset(offset)
  end

  def self.find_pending_invites_from(inviter, offset = 0)
    find_all_pending_invites_from(inviter, offset)
  end

  def self.find_pending_invites_count(inviter)
    find_all_pending_invites_from(inviter, 0, nil).reorder(nil).count
  end

  def self.find_all_redeemed_invites_from(inviter, offset = 0, limit = SiteSetting.invites_per_page)
    InvitedUser.includes(:invite)
      .includes(user: :user_stat)
      .where('invited_users.user_id IS NOT NULL')
      .where('invites.invited_by_id = ?', inviter.id)
      .order('user_stats.time_read DESC, invited_users.redeemed_at DESC')
      .limit(limit)
      .offset(offset)
      .references('invite')
      .references('user')
      .references('user_stat')
  end

  def self.find_redeemed_invites_from(inviter, offset = 0)
    find_all_redeemed_invites_from(inviter, offset)
  end

  def self.find_redeemed_invites_count(inviter)
    find_all_redeemed_invites_from(inviter, 0, nil).reorder(nil).count
  end

  def self.find_all_links_invites_from(inviter, offset = 0, limit = SiteSetting.invites_per_page)
    Invite.multiple_use_invites
      .includes(invited_groups: :group)
      .where(invited_by_id: inviter.id)
      .order('invites.updated_at DESC')
      .limit(limit)
      .offset(offset)
  end

  def self.find_links_invites_from(inviter, offset = 0)
    find_all_links_invites_from(inviter, offset)
  end

  def self.find_links_invites_count(inviter)
    find_all_links_invites_from(inviter, 0, nil).reorder(nil).count
  end

  def self.filter_by(email_or_username)
    if email_or_username
      where(
        '(LOWER(invites.email) LIKE :filter) or (LOWER(users.username) LIKE :filter)',
        filter: "%#{email_or_username.downcase}%"
      )
    else
      all
    end
  end

  def self.invalidate_for_email(email)
    i = Invite.find_by(email: Email.downcase(email))
    if i
      i.invalidated_at = Time.zone.now
      i.save
    end
    i
  end

  def self.redeem_from_email(email)
    invite = Invite.single_use_invites.find_by(email: Email.downcase(email))
    InviteRedeemer.new(invite: invite, email: invite.email).redeem if invite
    invite
  end

  def resend_invite
    self.update_columns(updated_at: Time.zone.now, expires_at: SiteSetting.invite_expiry_days.days.from_now)
    Jobs.enqueue(:invite_email, invite_id: self.id)
  end

  def self.resend_all_invites_from(user_id)
    Invite.single_use_invites
      .joins(:invited_users)
      .where('invited_users.user_id IS NULL AND invites.email IS NOT NULL AND invited_by_id = ?', user_id)
      .find_each do |invite|
      invite.resend_invite
    end
  end

  def self.rescind_all_expired_invites_from(user)
    Invite.single_use_invites
      .includes(:invited_users)
      .where('invited_users.user_id IS NULL AND invites.email IS NOT NULL AND invited_by_id = ? AND invites.expires_at < ?',
                user.id, Time.zone.now)
      .references('invited_users')
      .find_each do |invite|
      invite.trash!(user)
    end
  end

  def limit_invites_per_day
    RateLimiter.new(invited_by, "invites-per-day", SiteSetting.max_invites_per_day, 1.day.to_i)
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv", RailsMultisite::ConnectionManagement.current_db)
  end

  def ensure_max_redemptions_allowed
    if self.max_redemptions_allowed.nil? || self.max_redemptions_allowed == 1
      self.max_redemptions_allowed ||= 1
    else
      if !self.max_redemptions_allowed.between?(2, SiteSetting.invite_link_max_redemptions_limit)
        errors.add(:max_redemptions_allowed, I18n.t("invite_link.max_redemptions_limit", max_limit: SiteSetting.invite_link_max_redemptions_limit))
      end
    end
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
#
# Indexes
#
#  index_invites_on_email_and_invited_by_id  (email,invited_by_id)
#  index_invites_on_emailed_status           (emailed_status)
#  index_invites_on_invite_key               (invite_key) UNIQUE
#  index_invites_on_invited_by_id            (invited_by_id)
#
