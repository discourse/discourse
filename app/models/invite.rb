# frozen_string_literal: true

class Invite < ActiveRecord::Base
  class UserExists < StandardError; end
  include RateLimiter::OnCreateRecord
  include Trashable

  BULK_INVITE_EMAIL_LIMIT = 200

  rate_limit :limit_invites_per_day

  belongs_to :user
  belongs_to :topic
  belongs_to :invited_by, class_name: 'User'

  has_many :invited_groups
  has_many :groups, through: :invited_groups
  has_many :topic_invites
  has_many :topics, through: :topic_invites, source: :topic
  validates_presence_of :invited_by_id
  validates :email, email: true, format: { with: EmailValidator.email_regex }

  before_create do
    self.invite_key ||= SecureRandom.hex
  end

  before_validation do
    self.email = Email.downcase(email) unless email.nil?
  end

  validate :user_doesnt_already_exist
  attr_accessor :email_already_exists

  def self.emailed_status_types
    @emailed_status_types ||= Enum.new(not_required: 0, pending: 1, bulk_pending: 2, sending: 3, sent: 4)
  end

  def user_doesnt_already_exist
    @email_already_exists = false
    return if email.blank?
    user = Invite.find_user_by_email(email)

    if user && user.id != self.user_id
      @email_already_exists = true
      errors.add(:email)
    end
  end

  def redeemed?
    redeemed_at.present?
  end

  def expired?
    updated_at < SiteSetting.invite_expiry_days.days.ago
  end

  # link_valid? indicates whether the invite link can be used to log in to the site
  def link_valid?
    invalidated_at.nil?
  end

  def redeem(username: nil, name: nil, password: nil, user_custom_fields: nil, ip_address: nil)
    if !expired? && !destroyed? && link_valid?
      InviteRedeemer.new(self, username, name, password, user_custom_fields, ip_address).redeem
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

  # generate invite link
  def self.generate_invite_link(email, invited_by, topic = nil, group_ids = nil)
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

  def self.find_all_invites_from(inviter, offset = 0, limit = SiteSetting.invites_per_page)
    Invite.where(invited_by_id: inviter.id)
      .where('invites.email IS NOT NULL')
      .includes(user: :user_stat)
      .order("CASE WHEN invites.user_id IS NOT NULL THEN 0 ELSE 1 END, user_stats.time_read DESC, invites.redeemed_at DESC")
      .limit(limit)
      .offset(offset)
      .references('user_stats')
  end

  def self.find_pending_invites_from(inviter, offset = 0)
    find_all_invites_from(inviter, offset).where('invites.user_id IS NULL').order('invites.updated_at DESC')
  end

  def self.find_redeemed_invites_from(inviter, offset = 0)
    find_all_invites_from(inviter, offset).where('invites.user_id IS NOT NULL').order('invites.redeemed_at DESC')
  end

  def self.find_pending_invites_count(inviter)
    find_all_invites_from(inviter, 0, nil).where('invites.user_id IS NULL').reorder(nil).count
  end

  def self.find_redeemed_invites_count(inviter)
    find_all_invites_from(inviter, 0, nil).where('invites.user_id IS NOT NULL').reorder(nil).count
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
    invite = Invite.find_by(email: Email.downcase(email))
    InviteRedeemer.new(invite).redeem if invite
    invite
  end

  def resend_invite
    self.update_columns(updated_at: Time.zone.now)
    Jobs.enqueue(:invite_email, invite_id: self.id)
  end

  def self.resend_all_invites_from(user_id)
    Invite.where('invites.user_id IS NULL AND invites.email IS NOT NULL AND invited_by_id = ?', user_id).find_each do |invite|
      invite.resend_invite
    end
  end

  def self.rescind_all_expired_invites_from(user)
    Invite.where('invites.user_id IS NULL AND invites.email IS NOT NULL AND invited_by_id = ? AND invites.updated_at < ?',
                user.id, SiteSetting.invite_expiry_days.days.ago).find_each do |invite|
      invite.trash!(user)
    end
  end

  def limit_invites_per_day
    RateLimiter.new(invited_by, "invites-per-day", SiteSetting.max_invites_per_day, 1.day.to_i)
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv", RailsMultisite::ConnectionManagement.current_db)
  end
end

# == Schema Information
#
# Table name: invites
#
#  id             :integer          not null, primary key
#  invite_key     :string(32)       not null
#  email          :string
#  invited_by_id  :integer          not null
#  user_id        :integer
#  redeemed_at    :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  deleted_at     :datetime
#  deleted_by_id  :integer
#  invalidated_at :datetime
#  moderator      :boolean          default(FALSE), not null
#  custom_message :text
#  emailed_status :integer
#
# Indexes
#
#  index_invites_on_email_and_invited_by_id  (email,invited_by_id)
#  index_invites_on_emailed_status           (emailed_status)
#  index_invites_on_invite_key               (invite_key) UNIQUE
#  index_invites_on_invited_by_id            (invited_by_id)
#
