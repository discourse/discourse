require_dependency 'rate_limiter'

class Invite < ActiveRecord::Base
  class UserExists < StandardError; end
  include RateLimiter::OnCreateRecord
  include Trashable

  rate_limit :limit_invites_per_day

  belongs_to :user
  belongs_to :topic
  belongs_to :invited_by, class_name: 'User'

  has_many :invited_groups
  has_many :groups, through: :invited_groups
  has_many :topic_invites
  has_many :topics, through: :topic_invites, source: :topic
  validates_presence_of :invited_by_id
  validates :email, email: true

  before_create do
    self.invite_key ||= SecureRandom.hex
  end

  before_validation do
    self.email = Email.downcase(email) unless email.nil?
  end

  validate :user_doesnt_already_exist
  attr_accessor :email_already_exists

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
    created_at < SiteSetting.invite_expiry_days.days.ago
  end

  # link_valid? indicates whether the invite link can be used to log in to the site
  def link_valid?
    invalidated_at.nil?
  end

  def redeem(username: nil, name: nil, password: nil, user_custom_fields: nil)
    InviteRedeemer.new(self, username, name, password, user_custom_fields).redeem unless expired? || destroyed? || !link_valid?
  end

  def self.extend_permissions(topic, user, invited_by)
    if topic.private_message?
      topic.grant_permission_to_user(user.email)
    elsif topic.category && topic.category.groups.any?
      if Guardian.new(invited_by).can_invite_via_email?(topic)
        (topic.category.groups - user.groups).each do |group|
          group.add(user)
          GroupActionLogger.new(Discourse.system_user, group).log_add_user_to_group(user)
        end
      end
    end
  end

  def self.invite_by_email(email, invited_by, topic = nil, group_ids = nil, custom_message = nil)
    create_invite_by_email(email, invited_by,
      topic: topic,
      group_ids: group_ids,
      custom_message: custom_message,
      send_email: true
    )
  end

  # generate invite link
  def self.generate_invite_link(email, invited_by, topic = nil, group_ids = nil)
    invite = create_invite_by_email(email, invited_by,
      topic: topic,
      group_ids: group_ids,
      send_email: false
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
    send_email = opts[:send_email].nil? ? true : opts[:send_email]
    custom_message = opts[:custom_message]
    lower_email = Email.downcase(email)

    if user = find_user_by_email(lower_email)
      extend_permissions(topic, user, invited_by) if topic
      raise UserExists.new I18n.t("invite.user_exists", email: lower_email, username: user.username)
    end

    invite = Invite.with_deleted
      .where(email: lower_email, invited_by_id: invited_by.id)
      .order('created_at DESC')
      .first

    if invite && (invite.expired? || invite.deleted_at)
      invite.destroy
      invite = nil
    end

    invite.update_columns(created_at: Time.zone.now, updated_at: Time.zone.now) if invite

    if !invite
      create_args = { invited_by: invited_by, email: lower_email }
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
    else
      if topic && topic.category && Guardian.new(invited_by).can_invite_to?(topic)
        group_ids = topic.category.groups.where(automatic: false).pluck(:id) - invite.invited_groups.pluck(:group_id)
        group_ids.each { |group_id| invite.invited_groups.create!(group_id: group_id) }
      end
    end

    Jobs.enqueue(:invite_email, invite_id: invite.id) if send_email

    invite.reload
    invite
  end

  def self.find_user_by_email(email)
    User.with_email(email).where(staged: false).first
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

  INVITE_ORDER = <<~SQL
  SQL

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
    find_all_invites_from(inviter, offset).where('invites.user_id IS NULL').order('invites.created_at DESC')
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
    if invite
      InviteRedeemer.new(invite).redeem
    end
    invite
  end

  def resend_invite
    self.update_columns(created_at: Time.zone.now, updated_at: Time.zone.now)
    Jobs.enqueue(:invite_email, invite_id: self.id)
  end

  def self.resend_all_invites_from(user_id)
    Invite.where('invites.user_id IS NULL AND invites.email IS NOT NULL AND invited_by_id = ?', user_id).find_each do |invite|
      invite.resend_invite
    end
  end

  def self.rescind_all_invites_from(user)
    Invite.where('invites.user_id IS NULL AND invites.email IS NOT NULL AND invited_by_id = ?', user.id).find_each do |invite|
      invite.trash!(user)
    end
  end

  def limit_invites_per_day
    RateLimiter.new(invited_by, "invites-per-day", SiteSetting.max_invites_per_day, 1.day.to_i)
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv", RailsMultisite::ConnectionManagement.current_db)
  end

  def self.create_csv(file, name)
    extension = File.extname(file.original_filename)
    path = "#{Invite.base_directory}/#{name}#{extension}"
    FileUtils.mkdir_p(Pathname.new(path).dirname)
    File.open(path, "wb") { |f| f << file.tempfile.read }
    path
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
#
# Indexes
#
#  index_invites_on_email_and_invited_by_id  (email,invited_by_id)
#  index_invites_on_invite_key               (invite_key) UNIQUE
#
