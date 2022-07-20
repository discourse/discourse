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
  end

  def debug(message)
    @debug << message
  end

  def info(message = nil)
    @infos << message
  end

  def warn(message)
    @warnings << message
  end

  def error(message)
    @errors << message
  end

  def fatal(message)
    @fatals << message
  end

  def formatter
  end
end
