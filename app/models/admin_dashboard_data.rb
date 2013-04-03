require_dependency 'mem_info'

class AdminDashboardData

  REPORTS = ['visits', 'signups', 'topics', 'posts', 'flags', 'users_by_trust_level', 'likes', 'emails', 'private_messages']

  def self.fetch_all
    AdminDashboardData.new
  end

  def self.fetch_problems
    AdminDashboardData.new.problems
  end

  def as_json
    @json ||= {
      reports: REPORTS.map { |type| Report.find(type) },
      problems: problems,
      admins: User.admins.count,
      moderators: User.moderators.count
    }.merge(
      SiteSetting.version_checks? ? {version_check: DiscourseUpdates.check_version} : {}
    )
  end

  def problems
    [rails_env_check, host_names_check, gc_checks, sidekiq_check || clockwork_check, ram_check, facebook_config_check, twitter_config_check, github_config_check].compact
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

  def clockwork_check
    I18n.t('dashboard.clockwork_warning') unless Jobs::ClockworkHeartbeat.is_clockwork_running?
  end

  def ram_check
    I18n.t('dashboard.memory_warning') if MemInfo.new.mem_total and MemInfo.new.mem_total < 1_000_000
  end

  def facebook_config_check
    I18n.t('dashboard.facebook_config_warning') if SiteSetting.enable_facebook_logins and (!SiteSetting.facebook_app_id.present? or !SiteSetting.facebook_app_secret.present?)
  end

  def twitter_config_check
    I18n.t('dashboard.twitter_config_warning') if SiteSetting.enable_twitter_logins and (!SiteSetting.twitter_consumer_key.present? or !SiteSetting.twitter_consumer_secret.present?)
  end

  def github_config_check
    I18n.t('dashboard.github_config_warning') if SiteSetting.enable_github_logins and (!SiteSetting.github_client_id.present? or !SiteSetting.github_client_secret.present?)
  end
end