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
      each(&:run)
    end

    private

    attr_reader :checks
  end

  include ActiveSupport::Configurable

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
    ProblemCheck::RailsEnv,
    ProblemCheck::Ram,
    ProblemCheck::S3BackupConfig,
    ProblemCheck::S3Cdn,
    ProblemCheck::S3UploadConfig,
    ProblemCheck::SidekiqCheck,
    ProblemCheck::SubfolderEndsInSlash,
    ProblemCheck::TranslationOverrides,
    ProblemCheck::TwitterConfig,
    ProblemCheck::TwitterLogin,
    ProblemCheck::UnreachableThemes,
    ProblemCheck::WatchedWords,
  ].freeze

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

  def self.scheduled?
    perform_every.present?
  end
  delegate :scheduled?, to: :class

  def self.realtime?
    !scheduled?
  end
  delegate :realtime?, to: :class

  def self.call(data = {})
    new(data).call
  end

  def self.run(data = {}, &)
    new(data).run(&)
  end

  def initialize(data = {})
    @data = OpenStruct.new(data)
  end

  attr_reader :data

  def call
    raise NotImplementedError
  end

  def run
    problems = call

    yield(problems) if block_given?

    next_run_at = perform_every&.from_now

    if problems.empty?
      targets.each { |t| tracker(t).no_problem!(next_run_at:) }
    else
      problems
        .uniq(&:target)
        .each do |problem|
          tracker(problem.target).problem!(
            next_run_at:,
            details: translation_data.merge(problem.details).merge(base_path: Discourse.base_path),
          )
        end
    end

    problems
  end

  private

  def tracker(target = nil)
    ProblemCheckTracker[identifier, target]
  end

  def targets
    [nil]
  end

  def problem(override_key: nil, override_data: {})
    [
      Problem.new(
        message ||
          I18n.t(
            override_key || translation_key,
            base_path: Discourse.base_path,
            **override_data.merge(translation_data).symbolize_keys,
          ),
        priority: self.config.priority,
        identifier:,
      ),
    ]
  end

  def no_problem
    []
  end

  def message
    nil
  end

  def translation_key
    "dashboard.problem.#{identifier}"
  end

  def translation_data
    {}
  end
end
