require_dependency 'rate_limiter'

class Invite < ActiveRecord::Base
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
    u = User.find_by("email = ?", Email.downcase(email))
    if u && u.id != self.user_id
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

  def redeem
    InviteRedeemer.new(self).redeem unless expired? || destroyed? || !link_valid?
  end


  def add_groups_for_topic(topic)
    if topic.category
      (topic.category.groups - groups).each { |group| group.add(user) }
    end
  end

  def self.extend_permissions(topic, user, invited_by)
    if topic.private_message?
      topic.grant_permission_to_user(user.email)
    elsif topic.category && topic.category.groups.any?
      if Guardian.new(invited_by).can_invite_to?(topic) && !SiteSetting.enable_sso
        (topic.category.groups - user.groups).each { |group| group.add(user) }
      end
    end
  end

  def self.invite_by_email(email, invited_by, topic=nil, group_ids=nil)
    create_invite_by_email(email, invited_by, topic, group_ids, true)
  end

  # generate invite link
  def self.generate_invite_link(email, invited_by, topic=nil, group_ids=nil)
    invite = create_invite_by_email(email, invited_by, topic, group_ids, false)
    return "#{Discourse.base_url}/invites/#{invite.invite_key}" if invite
  end

  # Create an invite for a user, supplying an optional topic
  #
  # Return the previously existing invite if already exists. Returns nil if the invite can't be created.
  def self.create_invite_by_email(email, invited_by, topic=nil, group_ids=nil, send_email=true)
    lower_email = Email.downcase(email)
    user = User.find_by(email: lower_email)

    if user
      extend_permissions(topic, user, invited_by) if topic
      return nil
    end

    invite = Invite.with_deleted
                   .where(email: lower_email, invited_by_id: invited_by.id)
                   .order('created_at DESC')
                   .first

    if invite && (invite.expired? || invite.deleted_at)
      invite.destroy
      invite = nil
    end

    if !invite
      invite = Invite.create!(invited_by: invited_by, email: lower_email)
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
      if topic && topic.category # && Guardian.new(invited_by).can_invite_to?(topic)
        group_ids = topic.category.groups.pluck(:id) - invite.invited_groups.pluck(:group_id)
        group_ids.each { |group_id| invite.invited_groups.create!(group_id: group_id) }
      end
    end

    Jobs.enqueue(:invite_email, invite_id: invite.id) if send_email

    invite.reload
    invite
  end

  # generate invite tokens without email
  def self.generate_disposable_tokens(invited_by, quantity=nil, group_names=nil)
    invite_tokens = []
    quantity ||= 1
    group_ids = get_group_ids(group_names)

    quantity.to_i.times do
      invite = Invite.create!(invited_by: invited_by)
      group_ids = group_ids - invite.invited_groups.pluck(:group_id)
      group_ids.each do |group_id|
        invite.invited_groups.create!(group_id: group_id)
      end
      invite_tokens.push(invite.invite_key)
    end

    invite_tokens
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

  def self.find_all_invites_from(inviter, offset=0, limit=SiteSetting.invites_per_page)
    Invite.where(invited_by_id: inviter.id)
          .where('invites.email IS NOT NULL')
          .includes(:user => :user_stat)
          .order('CASE WHEN invites.user_id IS NOT NULL THEN 0 ELSE 1 END',
                 'user_stats.time_read DESC',
                 'invites.redeemed_at DESC')
          .limit(limit)
          .offset(offset)
          .references('user_stats')
  end

  def self.find_pending_invites_from(inviter, offset=0)
    find_all_invites_from(inviter, offset).where('invites.user_id IS NULL').order('invites.created_at DESC')
  end

  def self.find_redeemed_invites_from(inviter, offset=0)
    find_all_invites_from(inviter, offset).where('invites.user_id IS NOT NULL').order('invites.redeemed_at DESC')
  end

  def self.find_pending_invites_count(inviter)
    find_all_invites_from(inviter, 0, nil).where('invites.user_id IS NULL').count
  end

  def self.find_redeemed_invites_count(inviter)
    find_all_invites_from(inviter, 0, nil).where('invites.user_id IS NOT NULL').count
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

  def self.redeem_from_token(token, email, username=nil, name=nil, topic_id=nil)
    invite = Invite.find_by(invite_key: token)
    if invite
      invite.update_column(:email, email)
      invite.topic_invites.create!(invite_id: invite.id, topic_id: topic_id) if topic_id && Topic.find_by_id(topic_id) && !invite.topic_invites.pluck(:topic_id).include?(topic_id)
      user = InviteRedeemer.new(invite, username, name).redeem
    end
    user
  end

  def resend_invite
    self.update_columns(created_at: Time.zone.now, updated_at: Time.zone.now)
    Jobs.enqueue(:invite_email, invite_id: self.id)
  end

  def limit_invites_per_day
    RateLimiter.new(invited_by, "invites-per-day", SiteSetting.max_invites_per_day, 1.day.to_i)
  end

  def self.base_directory
    File.join(Rails.root, "public", "uploads", "csv", RailsMultisite::ConnectionManagement.current_db)
  end

  def self.chunk_path(identifier, filename, chunk_number)
    File.join(Invite.base_directory, "tmp", identifier, "#{filename}.part#{chunk_number}")
  end
end

# == Schema Information
#
# Table name: invites
#
#  id             :integer          not null, primary key
#  invite_key     :string(32)       not null
#  email          :string(255)
#  invited_by_id  :integer          not null
#  user_id        :integer
#  redeemed_at    :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  deleted_at     :datetime
#  deleted_by_id  :integer
#  invalidated_at :datetime
#
# Indexes
#
#  index_invites_on_email_and_invited_by_id  (email,invited_by_id)
#  index_invites_on_invite_key               (invite_key) UNIQUE
#
