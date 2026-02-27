# frozen_string_literal: true

class ProblemCheck
  class Collection
    include Enumerable

    def initialize(checks)
      @checks = checks
    end

    def each(...)
      checks.each(...)
    end

    def run_all
      select(&:enabled?).each { |check| check.each_target { |t| check.new(t).run } }
    end

    private

    attr_reader :checks
  end

  include ActiveSupport::Configurable

  config_accessor :enabled, default: true, instance_writer: false
  config_accessor :priority, default: "low", instance_writer: false

  # Determines if the check should be performed at a regular interval, and if
  # so how often. If left blank, the check will be performed every time the
  # admin dashboard is loaded, or the data is otherwise requested.
  #
  config_accessor :perform_every, default: nil, instance_writer: false

  # How many times the check should retry before registering a problem. Only
  # works for scheduled checks.
  #
  config_accessor :max_retries, default: 2, instance_writer: false

  # The retry delay after a failed check. Only works for scheduled checks with
  # more than one retry configured.
  #
  config_accessor :retry_after, default: 30.seconds, instance_writer: false

  # How many consecutive times the check can fail without notifying admins.
  # This can be used to give some leeway for transient problems. Note that
  # retries are not counted. So a check that ultimately fails after e.g. two
  # retries is counted as one "blip".
  #
  config_accessor :max_blips, default: 0, instance_writer: false

  # Indicates that the problem check is an "inline" check. This provides a
  # low level construct for registering problems ad-hoc within application
  # code, without having to extract the checking logic into a dedicated
  # problem check.
  #
  config_accessor :inline, default: false, instance_writer: false

  # Used to set up multiple targets for the check. For example, a check that
  # operates on groups may need to specify which groups to work on.
  #
  config_accessor :targets, default: -> { [NO_TARGET] }, instance_writer: false

  # Problem check classes need to be registered here in order to be enabled.
  #
  # Note: This list must come after the `config_accessor` declarations.
  #
  CORE_PROBLEM_CHECKS = [
    ProblemCheck::BadFaviconUrl,
    ProblemCheck::EmailPollingErroredRecently,
    ProblemCheck::FacebookConfig,
    ProblemCheck::FailingEmails,
    ProblemCheck::ForceHttps,
    ProblemCheck::GithubConfig,
    ProblemCheck::GoogleAnalyticsVersion,
    ProblemCheck::GoogleOauth2Config,
    ProblemCheck::GroupEmailCredentials,
    ProblemCheck::HostNames,
    ProblemCheck::ImageMagick,
    ProblemCheck::MissingMailgunApiKey,
    ProblemCheck::OutOfDateThemes,
    ProblemCheck::PollPop3Timeout,
    ProblemCheck::PollPop3AuthError,
    ProblemCheck::QqMailSmtp,
    ProblemCheck::RailsEnv,
    ProblemCheck::Ram,
    ProblemCheck::S3BackupConfig,
    ProblemCheck::S3Cdn,
    ProblemCheck::S3Credentials,
    ProblemCheck::S3UploadConfig,
    ProblemCheck::SidekiqCheck,
    ProblemCheck::SubfolderEndsInSlash,
    ProblemCheck::StarttlsDisabled,
    ProblemCheck::TranslationOverrides,
    ProblemCheck::TwitterConfig,
    ProblemCheck::TwitterLogin,
    ProblemCheck::UnreachableThemes,
    ProblemCheck::WatchedWords,
    ProblemCheck::UpcomingChangeStableOptedOut,
  ].freeze

  # To enforce the unique constraint in Postgres <15 we need a dummy
  # value, since the index considers NULLs to be distinct.
  NO_TARGET = "__NULL__"

  def self.[](key)
    key = key.to_sym

    checks.find { |c| c.identifier == key }
  end

  def self.checks
    Collection.new(DiscoursePluginRegistry.problem_checks.concat(CORE_PROBLEM_CHECKS))
  end

  def self.scheduled
    Collection.new(checks.select(&:scheduled?))
  end

  def self.realtime
    Collection.new(checks.select(&:realtime?))
  end

  def self.identifier
    name.demodulize.underscore.to_sym
  end
  delegate :identifier, to: :class

  def self.enabled?
    enabled
  end
  delegate :enabled?, to: :class

  def self.scheduled?
    perform_every.present?
  end
  delegate :scheduled?, to: :class

  def self.realtime?
    !scheduled? && !inline?
  end
  delegate :realtime?, to: :class

  def self.inline?
    inline
  end
  delegate :inline?, to: :class

  def self.targeted?
    targets.call != [ProblemCheck::NO_TARGET]
  end
  delegate :targeted?, to: :class

  def self.each_target(&)
    targets.call.each(&)
  end

  def self.cleanup_trackers
    current_targets = targets.call
    return if current_targets.empty?

    ProblemCheckTracker.where(identifier:).where.not(target: current_targets).destroy_all
  end

  def initialize(target = NO_TARGET)
    @target = target
  end

  attr_reader :target

  def call
    raise NotImplementedError
  end

  def run
    # Never run a targeted check with NO_TARGET (stale job or default targets used by mistake).
    if target == NO_TARGET && targeted?
      tracker.destroy
      return
    end

    # target is always a string when initializing this class, but the targets function
    # could return IDs from the DB. Make everything string so we don't return early all the time.
    if targeted? && targets.call.map(&:to_s).exclude?(target)
      tracker.destroy
      return
    end

    problem = call

    yield(problem) if block_given?

    next_run_at = perform_every&.from_now

    if problem.blank?
      tracker.no_problem!(next_run_at:)
    else
      tracker.problem!(
        next_run_at:,
        details: translation_data.merge(problem.details).merge(base_path: Discourse.base_path),
      )
    end
  end

  def tracker
    ProblemCheckTracker[identifier, target]
  end

  def ready_to_run?
    tracker.ready_to_run?
  end

  private

  def problem(target = nil, override_key: nil, override_data: {}, details: {})
    target_identifier = target.kind_of?(ActiveRecord::Base) ? target.id : target

    Problem.new(
      I18n.t(
        override_key || translation_key,
        base_path: Discourse.base_path,
        **override_data.merge(
          target.present? ? translation_data(target) : translation_data,
        ).symbolize_keys,
      ),
      priority: self.config.priority,
      identifier:,
      target: target_identifier,
      details:,
    )
  end

  def no_problem
    nil
  end

  def translation_key
    "dashboard.problem.#{identifier}"
  end

  def translation_data(target = nil)
    {}
  end
end
