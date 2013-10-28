require_dependency 'mem_info'

class AdminDashboardData

  REPORTS = [
    'visits',
    'signups',
    'topics',
    'posts',
    'flags',
    'users_by_trust_level',
    'likes',
    'bookmarks',
    'favorites',
    'emails',
    'user_to_user_private_messages',
    'system_private_messages',
    'moderator_warning_private_messages',
    'notify_moderators_private_messages',
    'notify_user_private_messages'
  ]

  def problems
    [ rails_env_check,
      ruby_version_check,
      host_names_check,
      gc_checks,
      sidekiq_check || queue_size_check,
      ram_check,
      facebook_config_check,
      twitter_config_check,
      github_config_check,
      s3_config_check,
      image_magick_check,
      failing_emails_check,
      default_logo_check,
      contact_email_check,
      send_consumer_email_check,
      title_check,
      site_description_check,
      access_password_removal,
      site_contact_username_check,
      notification_email_check ].compact
  end

  def self.fetch_stats
    AdminDashboardData.new
  end
  def self.fetch_cached_stats
    # The DashboardStats job is responsible for generating and caching this.
    stats = $redis.get(stats_cache_key)
    stats ? JSON.parse(stats) : nil
  end
  def self.stats_cache_key
    'dash-stats'
  end

  def self.fetch_problems
    AdminDashboardData.new.problems
  end

  def as_json
    @json ||= {
      reports: REPORTS.map { |type| Report.find(type).as_json },
      admins: User.admins.count,
      moderators: User.moderators.count,
      banned: User.banned.count,
      blocked: User.blocked.count,
      top_referrers: IncomingLinksReport.find('top_referrers').as_json,
      top_traffic_sources: IncomingLinksReport.find('top_traffic_sources').as_json,
      top_referred_topics: IncomingLinksReport.find('top_referred_topics').as_json,
      updated_at: Time.zone.now.as_json
    }
  end

  def self.recalculate_interval
    # Could be configurable, multisite need to support it.
    30 # minutes
  end

  def rails_env_check
    I18n.t("dashboard.rails_env_warning", env: Rails.env) unless Rails.env == 'production'
  end

  def host_names_check
    I18n.t("dashboard.host_names_warning") if ['localhost', 'production.localhost'].include?(Discourse.current_hostname)
  end

  def gc_checks
    I18n.t("dashboard.gc_warning") if ENV['RUBY_GC_MALLOC_LIMIT'].nil?
  end

  def sidekiq_check
    last_job_performed_at = Jobs.last_job_performed_at
    I18n.t('dashboard.sidekiq_warning') if Jobs.queued > 0 and (last_job_performed_at.nil? or last_job_performed_at < 2.minutes.ago)
  end

  def queue_size_check
    queue_size = Jobs.queued
    I18n.t('dashboard.queue_size_warning', queue_size: queue_size) unless queue_size < 100
  end

  def ram_check
    I18n.t('dashboard.memory_warning') if MemInfo.new.mem_total and MemInfo.new.mem_total < 1_000_000
  end

  def facebook_config_check
    I18n.t('dashboard.facebook_config_warning') if SiteSetting.enable_facebook_logins and (SiteSetting.facebook_app_id.blank? or SiteSetting.facebook_app_secret.blank?)
  end

  def twitter_config_check
    I18n.t('dashboard.twitter_config_warning') if SiteSetting.enable_twitter_logins and (SiteSetting.twitter_consumer_key.blank? or SiteSetting.twitter_consumer_secret.blank?)
  end

  def github_config_check
    I18n.t('dashboard.github_config_warning') if SiteSetting.enable_github_logins and (SiteSetting.github_client_id.blank? or SiteSetting.github_client_secret.blank?)
  end

  def s3_config_check
    I18n.t('dashboard.s3_config_warning') if SiteSetting.enable_s3_uploads and (SiteSetting.s3_access_key_id.blank? or SiteSetting.s3_secret_access_key.blank? or SiteSetting.s3_upload_bucket.blank?)
  end

  def image_magick_check
    I18n.t('dashboard.image_magick_warning') if SiteSetting.create_thumbnails and !system("command -v convert >/dev/null;")
  end

  def failing_emails_check
    num_failed_jobs = Jobs.num_email_retry_jobs
    I18n.t('dashboard.failing_emails_warning', num_failed_jobs: num_failed_jobs) if num_failed_jobs > 0
  end

  def default_logo_check
    if SiteSetting.logo_url =~ /#{SiteSetting.defaults[:logo_url].split('/').last}/ or
        SiteSetting.logo_small_url =~ /#{SiteSetting.defaults[:logo_small_url].split('/').last}/ or
        SiteSetting.favicon_url =~ /#{SiteSetting.defaults[:favicon_url].split('/').last}/
      I18n.t('dashboard.default_logo_warning')
    end
  end

  def contact_email_check
    return I18n.t('dashboard.contact_email_missing') if !SiteSetting.contact_email.present?
    return I18n.t('dashboard.contact_email_invalid') if !(SiteSetting.contact_email =~ User::EMAIL)
  end

  def title_check
    I18n.t('dashboard.title_nag') if SiteSetting.title == SiteSetting.defaults[:title]
  end

  def site_description_check
    return I18n.t('dashboard.site_description_missing') if !SiteSetting.site_description.present?
  end

  def send_consumer_email_check
    I18n.t('dashboard.consumer_email_warning') if Rails.env == 'production' and ActionMailer::Base.smtp_settings[:address] =~ /gmail\.com|live\.com|yahoo\.com/
  end

  def site_contact_username_check
    I18n.t('dashboard.site_contact_username_warning') if SiteSetting.site_contact_username.blank?
  end

  def notification_email_check
    I18n.t('dashboard.notification_email_warning') if SiteSetting.notification_email.blank?
  end

  def ruby_version_check
    I18n.t('dashboard.ruby_version_warning') if RUBY_VERSION == '2.0.0' and RUBY_PATCHLEVEL < 247
  end


  # TODO: generalize this method of putting i18n keys with expiry in redis
  #       that should be reported on the admin dashboard:
  def access_password_removal
    if i18n_key = $redis.get(AdminDashboardData.access_password_removal_key)
      I18n.t(i18n_key)
    end
  end
  def self.report_access_password_removal
    $redis.setex access_password_removal_key, 172_800, 'dashboard.access_password_removal'
  end

  private

    def self.access_password_removal_key
      'dash-data:access_password_removal'
    end

end
