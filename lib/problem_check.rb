# frozen_string_literal: true

class ProblemCheck
  include ActiveSupport::Configurable

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

  def self.call
    new.call
  end

  def call
    raise NotImplementedError
  end
end
