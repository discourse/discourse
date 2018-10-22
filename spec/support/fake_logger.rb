class FakeLogger
  attr_reader :warnings, :errors, :infos

  def initialize
    @warnings = []
    @errors = []
    @infos = []
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
end
