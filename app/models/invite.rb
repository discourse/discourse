require_dependency 'trashable'

class Invite < ActiveRecord::Base
  include Trashable

  belongs_to :user
  belongs_to :topic
  belongs_to :invited_by, class_name: 'User'

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
    if User.where("email = ?", Email.downcase(email)).exists?
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

  def redeem
    InviteRedeemer.new(self).redeem unless expired? || destroyed?
  end

end

# == Schema Information
#
# Table name: invites
#
#  id            :integer          not null, primary key
#  invite_key    :string(32)       not null
#  email         :string(255)      not null
#  invited_by_id :integer          not null
#  user_id       :integer
#  redeemed_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  deleted_at    :datetime
#  deleted_by_id :integer
#
# Indexes
#
#  index_invites_on_email_and_invited_by_id  (email,invited_by_id) UNIQUE
#  index_invites_on_invite_key               (invite_key) UNIQUE
#

