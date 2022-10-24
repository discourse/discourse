# frozen_string_literal: true

class FakeLogger
  attr_reader :debug, :infos, :warnings, :errors, :fatals
  attr_accessor :level

  def initialize
    @debug = []
    @infos = []
    @warnings = []
    @errors = []
    @fatals = []
    @level = Logger::DEBUG
  end

  def debug(message)
    @debug << message
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

  def warn(message)
    @warnings << message
  end

  def warn?
    @level <= Logger::WARN
  end

  def error(message)
    @errors << message
  end

  def error?
    @level <= Logger::ERROR
  end

  def fatal(message)
    @fatals << message
  end

  def fatal?
    @level <= Logger::FATAL
  end

  def formatter
  end
end
