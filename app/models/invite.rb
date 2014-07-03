class Invite < ActiveRecord::Base
  include Trashable

  belongs_to :user
  belongs_to :topic
  belongs_to :invited_by, class_name: 'User'

  has_many :invited_groups
  has_many :groups, through: :invited_groups
  has_many :topic_invites
  has_many :topics, through: :topic_invites, source: :topic
  validates_presence_of :email
  validates_presence_of :invited_by_id

  before_create do
    self.invite_key ||= SecureRandom.hex
  end

  before_save do
    self.email = Email.downcase(email)
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


  # Create an invite for a user, supplying an optional topic
  #
  # Return the previously existing invite if already exists. Returns nil if the invite can't be created.
  def self.invite_by_email(email, invited_by, topic=nil, group_ids=nil)
    lower_email = Email.downcase(email)
    user = User.find_by(email: lower_email)

    if user
      topic.grant_permission_to_user(lower_email) if topic && topic.private_message?
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
    end

    Jobs.enqueue(:invite_email, invite_id: invite.id)

    invite.reload
    invite
  end

  def self.find_all_invites_from(inviter)
    Invite.where(invited_by_id: inviter.id)
          .includes(:user => :user_stat)
          .order('CASE WHEN invites.user_id IS NOT NULL THEN 0 ELSE 1 END',
                 'user_stats.time_read DESC',
                 'invites.redeemed_at DESC')
          .limit(SiteSetting.invites_shown)
          .references('user_stats')
  end

  def self.find_redeemed_invites_from(inviter)
    find_all_invites_from(inviter).where('invites.user_id IS NOT NULL')
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

  def self.base_directory
    File.join(Rails.root, "public", "csv", RailsMultisite::ConnectionManagement.current_db)
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
#  email          :string(255)      not null
#  invited_by_id  :integer          not null
#  user_id        :integer
#  redeemed_at    :datetime
#  created_at     :datetime
#  updated_at     :datetime
#  deleted_at     :datetime
#  deleted_by_id  :integer
#  invalidated_at :datetime
#
# Indexes
#
#  index_invites_on_email_and_invited_by_id  (email,invited_by_id) UNIQUE
#  index_invites_on_invite_key               (invite_key) UNIQUE
#
