# frozen_string_literal: true

class SpamRule::AutoSilence

  attr_reader :group_message

  def initialize(user, post = nil)
    @user = user
    @post = post
  end

  def perform
    I18n.with_locale(SiteSetting.default_locale) do
      silence_user if should_autosilence?
    end
  end

  def self.prevent_posting?(user)
    user.blank? || user.silenced? || new(user).should_autosilence?
  end

  def should_autosilence?
    return false if @user.blank?
    return false if @user.staged?
    return false if @user.has_trust_level?(TrustLevel[1])

    SiteSetting.num_users_to_silence_new_user > 0 &&
      user_spam_stats.total_spam_score >= Reviewable.spam_score_to_silence_new_user &&
      user_spam_stats.spam_user_count >= SiteSetting.num_users_to_silence_new_user
  end

  def user_spam_stats
    return @user_spam_stats if @user_spam_stats

    params = {
      user_id: @user.id,
      spam_type: PostActionType.types[:spam],
      pending: ReviewableScore.statuses[:pending],
      agreed: ReviewableScore.statuses[:agreed]
    }

    result = DB.query(<<~SQL, params)
      SELECT COALESCE(SUM(rs.score), 0) AS total_spam_score,
        COUNT(DISTINCT rs.user_id) AS spam_user_count
      FROM reviewables AS r
      INNER JOIN reviewable_scores AS rs ON rs.reviewable_id = r.id
      WHERE r.target_created_by_id = :user_id
        AND rs.reviewable_score_type = :spam_type
        AND rs.status IN (:pending, :agreed)
    SQL

    @user_spam_stats = result[0]
  end

  def flagged_post_ids
    Post.where(user_id: @user.id)
      .where('spam_count > 0 OR off_topic_count > 0 OR inappropriate_count > 0')
      .pluck(:id)
  end

  def silence_user
    Post.transaction do

      silencer = UserSilencer.new(
        @user,
        Discourse.system_user,
        message: :too_many_spam_flags,
        post_id: @post&.id
      )

      if silencer.silence && SiteSetting.notify_mods_when_user_silenced
        @group_message = GroupMessage.create(Group[:moderators].name, :user_automatically_silenced, user: @user, limit_once_per: false)
      end
    end
  end
end
