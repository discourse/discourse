# frozen_string_literal: true

class AdminDashboardData
  include StatsCacheable

  cattr_reader :problem_syms, :problem_blocks, :problem_messages

  class Problem
    VALID_PRIORITIES = %w[low high].freeze

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
  SCHEDULED_PROBLEM_STORAGE_KEY = "admin-found-scheduled-problems-list"

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
    problems.concat(ProblemCheck.realtime.flat_map { |c| c.call.map(&:to_h) })

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

  def self.add_found_scheduled_check_problem(problem)
    problems = load_found_scheduled_check_problems
    if problem.identifier.present?
      return if problems.find { |p| p.identifier == problem.identifier }
    end
    set_found_scheduled_check_problem(problem)
  end

  def self.set_found_scheduled_check_problem(problem)
    Discourse.redis.rpush(SCHEDULED_PROBLEM_STORAGE_KEY, JSON.dump(problem.to_h))
  end

  def self.clear_found_scheduled_check_problems
    Discourse.redis.del(SCHEDULED_PROBLEM_STORAGE_KEY)
  end

  def self.clear_found_problem(identifier)
    problems = load_found_scheduled_check_problems
    problem = problems.find { |p| p.identifier == identifier }
    Discourse.redis.lrem(SCHEDULED_PROBLEM_STORAGE_KEY, 1, JSON.dump(problem.to_h))
  end

  def self.load_found_scheduled_check_problems
    found_problems = Discourse.redis.lrange(SCHEDULED_PROBLEM_STORAGE_KEY, 0, -1)

    return [] if found_problems.blank?

    found_problems.filter_map do |problem|
      begin
        Problem.from_h(JSON.parse(problem))
      rescue JSON::ParserError => err
        Discourse.warn_exception(
          err,
          message: "Error parsing found problem JSON in admin dashboard: #{problem}",
        )
        nil
      end
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

    @@problem_messages = %w[
      dashboard.bad_favicon_url
      dashboard.poll_pop3_timeout
      dashboard.poll_pop3_auth_error
    ]

    add_problem_check :force_https_check, :s3_config_check, :watched_words_check

    add_problem_check { sidekiq_check || queue_size_check }
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
    "dash-problems-started-at"
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
    if Discourse.redis.get(problem_message_key(i18n_key))
      I18n.t(i18n_key, base_path: Discourse.base_path)
    else
      nil
    end
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

  def sidekiq_check
    last_job_performed_at = Jobs.last_job_performed_at
    if Jobs.queued > 0 && (last_job_performed_at.nil? || last_job_performed_at < 2.minutes.ago)
      I18n.t("dashboard.sidekiq_warning")
    end
  end

  def queue_size_check
    queue_size = Jobs.queued
    I18n.t("dashboard.queue_size_warning", queue_size: queue_size) if queue_size >= 100_000
  end

  def s3_config_check
    # if set via global setting it is validated during the `use_s3?` call
    if !GlobalSetting.use_s3?
      bad_keys =
        (SiteSetting.s3_access_key_id.blank? || SiteSetting.s3_secret_access_key.blank?) &&
          !SiteSetting.s3_use_iam_profile

      if SiteSetting.enable_s3_uploads && (bad_keys || SiteSetting.s3_upload_bucket.blank?)
        return I18n.t("dashboard.s3_config_warning", base_path: Discourse.base_path)
      end

      if SiteSetting.backup_location == BackupLocationSiteSetting::S3 &&
           (bad_keys || SiteSetting.s3_backup_bucket.blank?)
        return I18n.t("dashboard.s3_backup_config_warning", base_path: Discourse.base_path)
      end
    end
    nil
  end

  def missing_mailgun_api_key
    return unless SiteSetting.reply_by_email_enabled
    return unless ActionMailer::Base.smtp_settings[:address]["smtp.mailgun.org"]
    return unless SiteSetting.mailgun_api_key.blank?
    I18n.t("dashboard.missing_mailgun_api_key")
  end

  def force_https_check
    return unless @opts[:check_force_https]
    unless SiteSetting.force_https
      I18n.t("dashboard.force_https_warning", base_path: Discourse.base_path)
    end
  end

  def watched_words_check
    WatchedWord.actions.keys.each do |action|
      begin
        WordWatcher.compiled_regexps_for_action(action, raise_errors: true)
      rescue RegexpError => e
        translated_action = I18n.t("admin_js.admin.watched_words.actions.#{action}")
        I18n.t(
          "dashboard.watched_word_regexp_error",
          base_path: Discourse.base_path,
          action: translated_action,
        )
      end
    end
    nil
  end
end
