# frozen_string_literal: true

class ProblemCheck
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

  def self.[](key)
    key = key.to_sym

    checks.find { |c| c.identifier == key }
  end

  def self.checks
    descendants
  end

  def self.scheduled
    checks.select(&:scheduled?)
  end

  def self.identifier
    name.demodulize.underscore.to_sym
  end
  delegate :identifier, to: :class

  def self.scheduled?
    perform_every.present?
  end
  delegate :scheduled?, to: :class

  def self.call(tracker)
    new.call(tracker)
  end

  def call(_tracker)
    raise NotImplementedError
  end

  private

  def problem
    [
      Problem.new(
        I18n.t(translation_key, base_path: Discourse.base_path),
        priority: self.config.priority,
        identifier:,
      ),
    ]
  end

  def no_problem
    []
  end

  def translation_key
    # TODO: Infer a default based on class name, then move translations in locale file.
    raise NotImplementedError
  end
end
