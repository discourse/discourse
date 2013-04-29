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

  class << self
    def fetch_all
      new
    end

    def fetch_problems
      new.problems
    end
  end

  def problems
    [ rails_env_check,
      host_names_check,
      gc_checks,
      sidekiq_check || queue_size_check || clockwork_check,
      ram_check,
      facebook_config_check,
      twitter_config_check,
      github_config_check,
      failing_emails_check,
      default_logo_check,
      contact_email_check,
      title_check ].compact
  end


  def as_json
    @json ||= {
      reports: REPORTS.map { |type| Report.find(type) },
      problems: problems,
      admins: User.admins.count,
      moderators: User.moderators.count
    }.merge(
      SiteSetting.version_checks? ? { version_check: DiscourseUpdates.check_version } : {}
    )
  end

  def rails_env_check
    I18n.t("dashboard.rails_env_warning", env: Rails.env) unless Rails.env.production?
  end

  def host_names_check
    I18n.t("dashboard.host_names_warning") if ['localhost', 'production.localhost'].include?(Discourse.current_hostname)
  end

  def gc_checks
    I18n.t("dashboard.gc_warning") if ENV['RUBY_GC_MALLOC_LIMIT'].nil?
  end

  def sidekiq_check
    last_job_performed_at = Jobs.last_job_performed_at
    I18n.t('dashboard.sidekiq_warning') if Jobs.queued > 0 && (last_job_performed_at.nil? || last_job_performed_at < 2.minutes.ago)
  end

  def clockwork_check
    I18n.t('dashboard.clockwork_warning') unless Jobs::ClockworkHeartbeat.is_clockwork_running?
  end

  def queue_size_check
    queue_size = Jobs.queued
    I18n.t('dashboard.queue_size_warning', queue_size: queue_size) unless queue_size < 100
  end

  def ram_check
    I18n.t('dashboard.memory_warning') if MemInfo.new.mem_total && MemInfo.new.mem_total < 1_000_000
  end

  def facebook_config_check
    I18n.t('dashboard.facebook_config_warning') if SiteSetting.enable_facebook_logins && (SiteSetting.facebook_app_id.blank? || SiteSetting.facebook_app_secret.blank?)
  end

  def twitter_config_check
    I18n.t('dashboard.twitter_config_warning') if SiteSetting.enable_twitter_logins && (SiteSetting.twitter_consumer_key.blank? || SiteSetting.twitter_consumer_secret.blank?)
  end

  def github_config_check
    I18n.t('dashboard.github_config_warning') if SiteSetting.enable_github_logins && (SiteSetting.github_client_id.blank? || SiteSetting.github_client_secret.blank?)
  end

  def failing_emails_check
    num_failed_jobs = Jobs.num_email_retry_jobs
    I18n.t('dashboard.failing_emails_warning', num_failed_jobs: num_failed_jobs) if num_failed_jobs > 0
  end

  def default_logo_check
    if SiteSetting.logo_url == SiteSetting.defaults[:logo_url] or
        SiteSetting.logo_small_url == SiteSetting.defaults[:logo_small_url] or
        SiteSetting.favicon_url == SiteSetting.defaults[:favicon_url]
      I18n.t('dashboard.default_logo_warning')
    end
  end

  def contact_email_check
    return I18n.t('dashboard.contact_email_missing') if SiteSetting.contact_email.blank?
    return I18n.t('dashboard.contact_email_invalid') unless SiteSetting.contact_email =~ User::EMAIL
  end

  def title_check
    I18n.t('dashboard.title_nag') if SiteSetting.title == SiteSetting.defaults[:title]
  end
end
