class UserOption < ActiveRecord::Base
  self.primary_key = :user_id
  belongs_to :user
  before_create :set_defaults

  after_save :update_tracked_topics

  def set_defaults
    self.email_always = SiteSetting.default_email_always
    self.mailing_list_mode = SiteSetting.default_email_mailing_list_mode
    self.email_direct = SiteSetting.default_email_direct
    self.automatically_unpin_topics = SiteSetting.default_topics_automatic_unpin
    self.email_private_messages = SiteSetting.default_email_private_messages

    self.enable_quoting = SiteSetting.default_other_enable_quoting
    self.external_links_in_new_tab = SiteSetting.default_other_external_links_in_new_tab
    self.dynamic_favicon = SiteSetting.default_other_dynamic_favicon
    self.disable_jump_reply = SiteSetting.default_other_disable_jump_reply
    self.edit_history_public = SiteSetting.default_other_edit_history_public

    self.new_topic_duration_minutes = SiteSetting.default_other_new_topic_duration_minutes
    self.auto_track_topics_after_msecs = SiteSetting.default_other_auto_track_topics_after_msecs


    if SiteSetting.default_email_digest_frequency.to_i <= 0
      self.email_digests = false
    else
      self.email_digests = true
      self.digest_after_days ||= SiteSetting.default_email_digest_frequency.to_i
    end

    true
  end

  def update_tracked_topics
    return unless auto_track_topics_after_msecs_changed?
    TrackedTopicsUpdater.new(id, auto_track_topics_after_msecs).call
  end

  def redirected_to_top_yet?
    last_redirected_to_top_at.present?
  end

  def update_last_redirected_to_top!
    key = "user:#{id}:update_last_redirected_to_top"
    delay = SiteSetting.active_user_rate_limit_secs

    # only update last_redirected_to_top_at once every minute
    return unless $redis.setnx(key, "1")
    $redis.expire(key, delay)

    # delay the update
    Jobs.enqueue_in(delay / 2, :update_top_redirection, user_id: self.id, redirected_at: Time.zone.now)
  end

  def should_be_redirected_to_top
    redirected_to_top.present?
  end

  def redirected_to_top
    # redirect is enabled
    return unless SiteSetting.redirect_users_to_top_page
    # top must be in the top_menu
    return unless SiteSetting.top_menu =~ /(^|\|)top(\||$)/i
    # not enough topics
    return unless period = SiteSetting.min_redirected_to_top_period

    if !user.seen_before? || (user.trust_level == 0 && !redirected_to_top_yet?)
      update_last_redirected_to_top!
      return {
        reason: I18n.t('redirected_to_top_reasons.new_user'),
        period: period
      }
    elsif user.last_seen_at < 1.month.ago
      update_last_redirected_to_top!
      return {
        reason: I18n.t('redirected_to_top_reasons.not_seen_in_a_month'),
        period: period
      }
    end

    # don't redirect to top
    nil
  end

  def treat_as_new_topic_start_date
    duration = new_topic_duration_minutes || SiteSetting.default_other_new_topic_duration_minutes.to_i
    times = [case duration
      when User::NewTopicDuration::ALWAYS
        user.created_at
      when User::NewTopicDuration::LAST_VISIT
        user.previous_visit_at || user.user_stat.new_since
      else
        duration.minutes.ago
    end, user.user_stat.new_since, Time.at(SiteSetting.min_new_topics_time).to_datetime]

    times.max
  end

end
