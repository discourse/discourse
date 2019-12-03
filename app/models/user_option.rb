# frozen_string_literal: true

class UserOption < ActiveRecord::Base
  self.primary_key = :user_id
  belongs_to :user
  before_create :set_defaults

  after_save :update_tracked_topics

  def self.ensure_consistency!
    sql = <<~SQL
      SELECT u.id FROM users u
      LEFT JOIN user_options o ON o.user_id = u.id
      WHERE o.user_id IS NULL
    SQL

    DB.query_single(sql).each do |id|
      UserOption.create(user_id: id)
    end
  end

  def self.previous_replies_type
    @previous_replies_type ||= Enum.new(always: 0, unless_emailed: 1, never: 2)
  end

  def self.like_notification_frequency_type
    @like_notification_frequency_type ||= Enum.new(always: 0, first_time_and_daily: 1, first_time: 2, never: 3)
  end

  def self.text_sizes
    @text_sizes ||= Enum.new(normal: 0, larger: 1, largest: 2, smaller: 3)
  end

  def self.title_count_modes
    @title_count_modes ||= Enum.new(notifications: 0, contextual: 1)
  end

  def self.email_level_types
    @email_level_type ||= Enum.new(always: 0, only_when_away: 1, never: 2)
  end

  validates :text_size_key, inclusion: { in: UserOption.text_sizes.values }
  validates :email_level, inclusion: { in: UserOption.email_level_types.values }
  validates :email_messages_level, inclusion: { in: UserOption.email_level_types.values }
  validates :timezone, timezone: true

  def set_defaults
    self.mailing_list_mode = SiteSetting.default_email_mailing_list_mode
    self.mailing_list_mode_frequency = SiteSetting.default_email_mailing_list_mode_frequency
    self.email_level = SiteSetting.default_email_level
    self.email_messages_level = SiteSetting.default_email_messages_level
    self.automatically_unpin_topics = SiteSetting.default_topics_automatic_unpin
    self.email_previous_replies = SiteSetting.default_email_previous_replies
    self.email_in_reply_to = SiteSetting.default_email_in_reply_to

    self.enable_quoting = SiteSetting.default_other_enable_quoting
    self.enable_defer = SiteSetting.default_other_enable_defer
    self.external_links_in_new_tab = SiteSetting.default_other_external_links_in_new_tab
    self.dynamic_favicon = SiteSetting.default_other_dynamic_favicon

    self.new_topic_duration_minutes = SiteSetting.default_other_new_topic_duration_minutes
    self.auto_track_topics_after_msecs = SiteSetting.default_other_auto_track_topics_after_msecs
    self.notification_level_when_replying = SiteSetting.default_other_notification_level_when_replying

    self.like_notification_frequency = SiteSetting.default_other_like_notification_frequency

    if SiteSetting.default_email_digest_frequency.to_i <= 0
      self.email_digests = false
    else
      self.email_digests = true
      self.digest_after_minutes ||= SiteSetting.default_email_digest_frequency.to_i
    end

    self.include_tl0_in_digests = SiteSetting.default_include_tl0_in_digests

    self.text_size = SiteSetting.default_text_size

    self.title_count_mode = SiteSetting.default_title_count_mode

    true
  end

  def mailing_list_mode
    return false if SiteSetting.disable_mailing_list_mode
    super
  end

  def redirected_to_top_yet?
    last_redirected_to_top_at.present?
  end

  def update_last_redirected_to_top!
    key = "user:#{id}:update_last_redirected_to_top"
    delay = SiteSetting.active_user_rate_limit_secs

    # only update last_redirected_to_top_at once every minute
    return unless Discourse.redis.setnx(key, "1")
    Discourse.redis.expire(key, delay)

    # delay the update
    Jobs.enqueue_in(delay / 2, :update_top_redirection, user_id: self.user_id, redirected_at: Time.zone.now)
  end

  def should_be_redirected_to_top
    redirected_to_top.present?
  end

  def redirected_to_top
    # redirect is enabled
    return unless SiteSetting.redirect_users_to_top_page

    # PERF: bypass min_redirected_to_top query for users that were seen already
    return if user.trust_level > 0 && user.last_seen_at && user.last_seen_at > 1.month.ago

    # top must be in the top_menu
    return unless SiteSetting.top_menu[/\btop\b/i]

    # not enough topics
    return unless period = SiteSetting.min_redirected_to_top_period(1.day.ago)

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
    times = [
      case duration
      when User::NewTopicDuration::ALWAYS
        user.created_at
      when User::NewTopicDuration::LAST_VISIT
        user.previous_visit_at || user.user_stat.new_since
      else
        duration.minutes.ago
      end,
      user.user_stat.new_since,
      Time.at(SiteSetting.min_new_topics_time).to_datetime
    ]

    times.max
  end

  def homepage
    case homepage_id
    when 1 then "latest"
    when 2 then "categories"
    when 3 then "unread"
    when 4 then "new"
    when 5 then "top"
    else SiteSetting.homepage
    end
  end

  def text_size
    UserOption.text_sizes[text_size_key]
  end

  def text_size=(value)
    self.text_size_key = UserOption.text_sizes[value.to_sym]
  end

  def title_count_mode
    UserOption.title_count_modes[title_count_mode_key]
  end

  def title_count_mode=(value)
    self.title_count_mode_key = UserOption.title_count_modes[value.to_sym]
  end

  private

  def update_tracked_topics
    return unless saved_change_to_auto_track_topics_after_msecs?
    TrackedTopicsUpdater.new(id, auto_track_topics_after_msecs).call
  end

end

# TODO: Drop disable_jump_reply column. Functionality removed April 2019

# == Schema Information
#
# Table name: user_options
#
#  user_id                          :integer          not null, primary key
#  mailing_list_mode                :boolean          default(FALSE), not null
#  email_digests                    :boolean
#  external_links_in_new_tab        :boolean          default(FALSE), not null
#  enable_quoting                   :boolean          default(TRUE), not null
#  dynamic_favicon                  :boolean          default(FALSE), not null
#  disable_jump_reply               :boolean          default(FALSE), not null
#  automatically_unpin_topics       :boolean          default(TRUE), not null
#  digest_after_minutes             :integer
#  auto_track_topics_after_msecs    :integer
#  new_topic_duration_minutes       :integer
#  last_redirected_to_top_at        :datetime
#  email_previous_replies           :integer          default(2), not null
#  email_in_reply_to                :boolean          default(TRUE), not null
#  like_notification_frequency      :integer          default(1), not null
#  mailing_list_mode_frequency      :integer          default(1), not null
#  include_tl0_in_digests           :boolean          default(FALSE)
#  notification_level_when_replying :integer
#  theme_key_seq                    :integer          default(0), not null
#  allow_private_messages           :boolean          default(TRUE), not null
#  homepage_id                      :integer
#  theme_ids                        :integer          default([]), not null, is an Array
#  hide_profile_and_presence        :boolean          default(FALSE), not null
#  text_size_key                    :integer          default(0), not null
#  text_size_seq                    :integer          default(0), not null
#  email_level                      :integer          default(1), not null
#  email_messages_level             :integer          default(0), not null
#  title_count_mode_key             :integer          default(0), not null
#  enable_defer                     :boolean          default(FALSE), not null
#  timezone                         :string
#
# Indexes
#
#  index_user_options_on_user_id  (user_id) UNIQUE
#
