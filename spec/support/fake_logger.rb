class FakeLogger
  attr_reader :warnings, :errors

  def initialize
    @warnings = []
    @errors = []
  end

  def warn(message)
    @warnings << message
  end

  def error(message)
    @errors << message
  end
end
