# frozen_string_literal: true

class FakeLogger
  attr_reader :debugs, :infos, :warnings, :errors, :fatals, :severities
  attr_accessor :level

  def initialize
    @debugs = []
    @infos = []
    @warnings = []
    @errors = []
    @fatals = []
    @level = Logger::DEBUG
    @severities = { 0 => :debugs, 1 => :infos, 2 => :warnings, 3 => :errors, 4 => :fatals }
  end

  def all_messages_to_s
    @debugs.each { |msg| puts "DEBUG: #{msg}" }
    @infos.each { |msg| puts "INFO: #{msg}" }
    @warnings.each { |msg| puts "WARN: #{msg}" }
    @errors.each { |msg| puts "ERROR: #{msg}" }
    @fatals.each { |msg| puts "FATAL: #{msg}" }
  end

  def debug(message = nil)
    @debugs << message
  end

  def debug?
    @level <= Logger::DEBUG
  end

  def info(message = nil)
    @infos << message
  end

  def info?
    @level <= Logger::INFO
  end

  def warn(message = nil)
    @warnings << message
  end

  def warn?
    @level <= Logger::WARN
  end

  def error(message = nil)
    @errors << message
  end

  def error?
    @level <= Logger::ERROR
  end

  def fatal(message = nil)
    @fatals << message
  end

  def fatal?
    @level <= Logger::FATAL
  end

  def formatter
  end

  def add(severity, message = nil, progname = nil)
    public_send(severities[severity]) << message
  end

  def broadcasts
    [self]
  end
end
