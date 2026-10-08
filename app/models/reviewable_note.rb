# frozen_string_literal: true

class ReviewableNote < ActiveRecord::Base
  MAX_CONTENT_LENGTH = 2000

  belongs_to :reviewable
  belongs_to :user

  validates :content, presence: true, length: { minimum: 1, maximum: MAX_CONTENT_LENGTH }
  validates :reviewable_id, presence: true
  validates :user_id, presence: true
  validate :mention_limit

  scope :ordered, -> { order(:created_at) }

  attr_reader :unnotified_usernames

  after_create :notify_mentions

  private

  def mentioned_usernames
    if @analyzed_content != content
      @analyzed_content = content.dup
      @mentioned_usernames = PostAnalyzer.new(content, nil).raw_mentions
    end
    @mentioned_usernames || []
  end

  def mention_limit
    return if !SiteSetting.enable_mentions || user.nil? || user.staff? || content.blank?

    trusted = user.has_trust_level?(TrustLevel[1])
    limit = trusted ? SiteSetting.max_mentions_per_post : SiteSetting.newuser_max_mentions_per_post
    return if mentioned_usernames.size <= limit

    key = limit.zero? ? "no_mentions_allowed" : "too_many_mentions"
    key += "_newuser" if !trusted
    errors.add(:base, I18n.t(key, count: limit))
  end

  def notify_mentions
    @unnotified_usernames = []
    return if !SiteSetting.enable_mentions

    usernames = mentioned_usernames
    return if usernames.empty?

    mentioned_users = User.where(username_lower: usernames).where.not(id: user_id).to_a
    screener = UserCommScreener.new(acting_user: user, target_user_ids: mentioned_users.map(&:id))

    mentioned_users.each do |mentioned_user|
      next if mentioned_user.bot?

      if !mentioned_user.guardian.can_see_review_queue? ||
           !Reviewable.viewable_by(mentioned_user, preload: false).exists?(id: reviewable_id)
        @unnotified_usernames << mentioned_user.username
        next
      end

      next if screener.ignoring_or_muting_actor?(mentioned_user.id)

      mentioned_user.notifications.create!(
        notification_type: Notification.types[:mentioned],
        data: {
          reviewable_id: reviewable_id,
          reviewable_note_id: id,
          topic_title: reviewable.title_for_notification(mentioned_user),
          display_username: user.username,
        }.to_json,
        skip_send_email: true,
      )
    end
  end
end

# == Schema Information
#
# Table name: reviewable_notes
#
#  id            :bigint           not null, primary key
#  content       :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  reviewable_id :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_reviewable_notes_on_reviewable_id                 (reviewable_id)
#  index_reviewable_notes_on_reviewable_id_and_created_at  (reviewable_id,created_at)
#  index_reviewable_notes_on_user_id                       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (reviewable_id => reviewables.id)
#  fk_rails_...  (user_id => users.id)
#
