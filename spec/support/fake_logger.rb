# frozen_string_literal: true

class FakeLogger
  attr_reader :warnings, :errors, :infos, :fatals
  attr_accessor :level

  def initialize
    @warnings = []
    @errors = []
    @debug = []
    @infos = []
    @fatals = []
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

  def debug(message)
    @debug << message
  end

  def formatter
  end
end
