# frozen_string_literal: true

class FakeLogger
  attr_reader :warnings, :errors, :infos, :fatals

  def initialize
    @warnings = []
    @errors = []
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

  def formatter
  end
end
