# frozen_string_literal: true

class AdminDashboardData
  include StatsCacheable

  cattr_reader :problem_syms,
    :problem_blocks,
    :problem_messages,
    :problem_scheduled_check_blocks

  class Problem
    VALID_PRIORITIES = ["low", "high"].freeze

    attr_reader :message, :priority, :identifier

    def initialize(message, priority: "low", identifier: nil)
      @message = message
      @priority = VALID_PRIORITIES.include?(priority) ? priority : "low"
      @identifier = identifier
    end

    def to_s
      @message
    end

    def to_h
      { message: message, priority: priority, identifier: identifier }
    end

    def self.from_h(h)
      h = h.with_indifferent_access
      return if h[:message].blank?
      new(h[:message], priority: h[:priority], identifier: h[:identifier])
    end
  end

  # kept for backward compatibility
  GLOBAL_REPORTS ||= []

  PROBLEM_MESSAGE_PREFIX = "admin-problem:"
  SCHEDULED_PROBLEM_STORAGE_KEY = "admin-found-scheduled-problems"

  def initialize(opts = {})
    @opts = opts
  end

  def get_json
    {}
  end

  def as_json(_options = nil)
    @json ||= get_json
  end

  def problems
    problems = []
    self.class.problem_syms.each do |sym|
      message = public_send(sym)
      problems << Problem.new(message) if message.present?
    end
    self.class.problem_blocks.each do |blk|
      message = instance_exec(&blk)
      problems << Problem.new(message) if message.present?
    end
    self.class.problem_messages.each do |i18n_key|
      message = self.class.problem_message_check(i18n_key)
      problems << Problem.new(message) if message.present?
    end
    problems += self.class.load_found_scheduled_check_problems
    problems.compact!

    if problems.empty?
      self.class.clear_problems_started
    else
      self.class.set_problems_started
    end

    problems
  end

  def self.add_problem_check(*syms, &blk)
    @@problem_syms.push(*syms) if syms
    @@problem_blocks << blk if blk
  end

  def self.add_scheduled_problem_check(check_identifier, &blk)
    @@problem_scheduled_check_blocks[check_identifier] = blk
  end

  def self.add_found_scheduled_check_problem(problem)
    problems = load_found_scheduled_check_problems
    if problem.identifier.present?
      return if problems.find { |p| p.identifier == problem.identifier }
    end
    problems << problem
    set_found_scheduled_check_problems(problems)
  end

  def self.set_found_scheduled_check_problems(problems)
    Discourse.redis.setex(SCHEDULED_PROBLEM_STORAGE_KEY, 300, JSON.dump(problems.map(&:to_h)))
  end

  def self.clear_found_scheduled_check_problems
    Discourse.redis.del(SCHEDULED_PROBLEM_STORAGE_KEY)
  end

  def self.clear_found_problem(identifier)
    problems = load_found_scheduled_check_problems
    problems.reject! { |p| p.identifier == identifier }
    set_found_scheduled_check_problems(problems)
  end

  def self.load_found_scheduled_check_problems
    found_problems_json = Discourse.redis.get(SCHEDULED_PROBLEM_STORAGE_KEY)
    return [] if found_problems_json.blank?
    begin
      JSON.parse(found_problems_json).map do |problem|
        Problem.from_h(problem)
      end
    rescue JSON::ParserError => err
      Discourse.warn_exception(err, message: "Error parsing found problem JSON in admin dashboard: #{found_problems_json}")
      []
    end
  end

  def self.register_default_scheduled_problem_checks
    add_scheduled_problem_check(:group_smtp_credentials) do
      problems = GroupEmailCredentialsCheck.run
      problems.map do |p|
        problem_message = I18n.t(
          "dashboard.group_email_credentials_warning",
          {
            base_path: Discourse.base_path,
            group_name: p[:group_name],
            group_full_name: p[:group_full_name],
            error: p[:message]
          }
        )
        Problem.new(problem_message, priority: "high", identifier: "group_#{p[:group_id]}_email_credentials")
      end
    end
  end

  def self.execute_scheduled_checks
    found_problems = []
    problem_scheduled_check_blocks.each do |check_identifier, blk|
      problems = nil

      begin
        problems = instance_exec(&blk)
      rescue StandardError => err
        Discourse.warn_exception(err, message: "A scheduled admin dashboard problem check (#{check_identifier}) errored.")
        # we don't want to hold up other checks because this one errored
        next
      end

      found_problems += Array.wrap(problems)
    end

    found_problems.compact.each do |problem|
      next if !problem.is_a?(Problem)
      add_found_scheduled_check_problem(problem)
    end
  end

  ##
  # We call this method in the class definition below
  # so all of the problem checks in this class are registered on
  # boot. These problem checks are run when the problems are loaded in
  # the admin dashboard controller.
  #
  # This method also can be used in testing to reset checks between
  # tests. It will also fire multiple times in development mode because
  # classes are not cached.
  def self.reset_problem_checks
    @@problem_syms = []
    @@problem_blocks = []
    @@problem_scheduled_check_blocks = {}

    @@problem_messages = [
      'dashboard.bad_favicon_url',
      'dashboard.poll_pop3_timeout',
      'dashboard.poll_pop3_auth_error',
    ]

    add_problem_check :rails_env_check, :host_names_check, :force_https_check,
                      :ram_check, :google_oauth2_config_check,
                      :facebook_config_check, :twitter_config_check,
                      :github_config_check, :s3_config_check, :s3_cdn_check,
                      :image_magick_check, :failing_emails_check,
                      :subfolder_ends_in_slash_check,
                      :email_polling_errored_recently,
                      :out_of_date_themes, :unreachable_themes, :watched_words_check

    register_default_scheduled_problem_checks

    add_problem_check do
      sidekiq_check || queue_size_check
    end
  end
  reset_problem_checks

  def self.fetch_stats
    new.as_json
  end

  def self.reports(source)
    source.map { |type| Report.find(type).as_json }
  end

  def self.stats_cache_key
    "dashboard-data-#{Report::SCHEMA_VERSION}"
  end

  def self.problems_started_key
    'dash-problems-started-at'
  end

  def self.set_problems_started
    existing_time = Discourse.redis.get(problems_started_key)
    Discourse.redis.setex(problems_started_key, 14.days.to_i, existing_time || Time.zone.now.to_s)
  end

  def self.clear_problems_started
    Discourse.redis.del problems_started_key
  end

  def self.problems_started_at
    s = Discourse.redis.get(problems_started_key)
    s ? Time.zone.parse(s) : nil
  end

  def self.fetch_problems(opts = {})
    new(opts).problems
  end

  def self.problem_message_check(i18n_key)
    Discourse.redis.get(problem_message_key(i18n_key)) ? I18n.t(i18n_key, base_path: Discourse.base_path) : nil
  end

  ##
  # Arbitrary messages cannot be added here, they must already be defined
  # in the @problem_messages array which is defined in reset_problem_checks.
  # The array is iterated over and each key that exists in redis will be added
  # to the final problems output in #problems.
  def self.add_problem_message(i18n_key, expire_seconds = nil)
    if expire_seconds.to_i > 0
      Discourse.redis.setex problem_message_key(i18n_key), expire_seconds.to_i, 1
    else
      Discourse.redis.set problem_message_key(i18n_key), 1
    end
  end

  def self.clear_problem_message(i18n_key)
    Discourse.redis.del problem_message_key(i18n_key)
  end

  def self.problem_message_key(i18n_key)
    "#{PROBLEM_MESSAGE_PREFIX}#{i18n_key}"
  end

  def rails_env_check
    I18n.t("dashboard.rails_env_warning", env: Rails.env) unless Rails.env.production?
  end

  def host_names_check
    I18n.t("dashboard.host_names_warning") if ['localhost', 'production.localhost'].include?(Discourse.current_hostname)
  end

  def sidekiq_check
    last_job_performed_at = Jobs.last_job_performed_at
    I18n.t('dashboard.sidekiq_warning') if Jobs.queued > 0 && (last_job_performed_at.nil? || last_job_performed_at < 2.minutes.ago)
  end

  def queue_size_check
    queue_size = Jobs.queued
    I18n.t('dashboard.queue_size_warning', queue_size: queue_size) unless queue_size < 100_000
  end

  def ram_check
    I18n.t('dashboard.memory_warning') if MemInfo.new.mem_total && MemInfo.new.mem_total < 950_000
  end

  def google_oauth2_config_check
    if SiteSetting.enable_google_oauth2_logins && (SiteSetting.google_oauth2_client_id.blank? || SiteSetting.google_oauth2_client_secret.blank?)
      I18n.t('dashboard.google_oauth2_config_warning', base_path: Discourse.base_path)
    end
  end

  def facebook_config_check
    if SiteSetting.enable_facebook_logins && (SiteSetting.facebook_app_id.blank? || SiteSetting.facebook_app_secret.blank?)
      I18n.t('dashboard.facebook_config_warning', base_path: Discourse.base_path)
    end
  end

  def twitter_config_check
    if SiteSetting.enable_twitter_logins && (SiteSetting.twitter_consumer_key.blank? || SiteSetting.twitter_consumer_secret.blank?)
      I18n.t('dashboard.twitter_config_warning', base_path: Discourse.base_path)
    end
  end

  def github_config_check
    if SiteSetting.enable_github_logins && (SiteSetting.github_client_id.blank? || SiteSetting.github_client_secret.blank?)
      I18n.t('dashboard.github_config_warning', base_path: Discourse.base_path)
    end
  end

  def s3_config_check
    # if set via global setting it is validated during the `use_s3?` call
    if !GlobalSetting.use_s3?
      bad_keys = (SiteSetting.s3_access_key_id.blank? || SiteSetting.s3_secret_access_key.blank?) && !SiteSetting.s3_use_iam_profile

      if SiteSetting.enable_s3_uploads && (bad_keys || SiteSetting.s3_upload_bucket.blank?)
        return I18n.t('dashboard.s3_config_warning', base_path: Discourse.base_path)
      end

      if SiteSetting.backup_location == BackupLocationSiteSetting::S3 && (bad_keys || SiteSetting.s3_backup_bucket.blank?)
        return I18n.t('dashboard.s3_backup_config_warning', base_path: Discourse.base_path)
      end
    end
    nil
  end

  def s3_cdn_check
    if (GlobalSetting.use_s3? || SiteSetting.enable_s3_uploads) && SiteSetting.Upload.s3_cdn_url.blank?
      I18n.t('dashboard.s3_cdn_warning')
    end
  end

  def image_magick_check
    I18n.t('dashboard.image_magick_warning') if SiteSetting.create_thumbnails && !system("command -v convert >/dev/null;")
  end

  def failing_emails_check
    num_failed_jobs = Jobs.num_email_retry_jobs
    I18n.t('dashboard.failing_emails_warning', num_failed_jobs: num_failed_jobs, base_path: Discourse.base_path) if num_failed_jobs > 0
  end

  def subfolder_ends_in_slash_check
    I18n.t('dashboard.subfolder_ends_in_slash') if Discourse.base_path =~ /\/$/
  end

  def email_polling_errored_recently
    errors = Jobs::PollMailbox.errors_in_past_24_hours
    I18n.t('dashboard.email_polling_errored_recently', count: errors, base_path: Discourse.base_path) if errors > 0
  end

  def missing_mailgun_api_key
    return unless SiteSetting.reply_by_email_enabled
    return unless ActionMailer::Base.smtp_settings[:address]['smtp.mailgun.org']
    return unless SiteSetting.mailgun_api_key.blank?
    I18n.t('dashboard.missing_mailgun_api_key')
  end

  def force_https_check
    return unless @opts[:check_force_https]
    I18n.t('dashboard.force_https_warning', base_path: Discourse.base_path) unless SiteSetting.force_https
  end

  def watched_words_check
    WatchedWord.actions.keys.each do |action|
      begin
        WordWatcher.word_matcher_regexp(action, raise_errors: true)
      rescue RegexpError => e
        translated_action = I18n.t("admin_js.admin.watched_words.actions.#{action}")
        I18n.t('dashboard.watched_word_regexp_error', base_path: Discourse.base_path, action: translated_action)
      end
    end
    nil
  end

  def out_of_date_themes
    old_themes = RemoteTheme.out_of_date_themes
    return unless old_themes.present?

    themes_html_format(old_themes, 'dashboard.out_of_date_themes')
  end

  def unreachable_themes
    themes = RemoteTheme.unreachable_themes
    return unless themes.present?

    themes_html_format(themes, 'dashboard.unreachable_themes')
  end

  private

  def themes_html_format(themes, i18n_key)
    html = themes.map do |name, id|
      "<li><a href=\"/admin/customize/themes/#{id}\">#{CGI.escapeHTML(name)}</a></li>"
    end.join("\n")

    "#{I18n.t(i18n_key)}<ul>#{html}</ul>"
  end
end
