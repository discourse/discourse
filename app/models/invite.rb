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
    result = nil
    Invite.transaction do
      # Avoid a race condition
      row_count = Invite.update_all('redeemed_at = CURRENT_TIMESTAMP',
                                    ['id = ? AND redeemed_at IS NULL AND created_at >= ?', id, SiteSetting.invite_expiry_days.days.ago])

      if row_count == 1

        # Create the user if we are redeeming the invite and the user doesn't exist
        result = User.where(email: email).first
        result ||= User.create_for_email(email, trust_level: SiteSetting.default_invitee_trust_level)
        result.send_welcome_message = false

        # If there are topic invites for private topics
        topics.private_messages.each do |t|
          t.topic_allowed_users.create(user_id: result.id)
        end

        # Check for other invites by the same email. Don't redeem them, but approve their
        # topics.
        Invite.where('invites.email = ? and invites.id != ?', email, id).includes(:topics).where(topics: { archetype: Archetype::private_message }).each do |i|
          i.topics.each do |t|
            t.topic_allowed_users.create(user_id: result.id)
          end
        end

        if Invite.update_all(['user_id = ?', result.id], ['email = ?', email]) == 1
          result.send_welcome_message = true
        end

          # Notify the invitee
          invited_by.notifications.create(notification_type: Notification.types[:invitee_accepted],
                                          data: { display_username: result.username }.to_json)

      else
        # Otherwise return the existing user
        result = User.where(email: email).first
      end
    end

    result
  end

end
