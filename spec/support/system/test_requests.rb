# frozen_string_literal: true

class SystemTestRequests
  def initialize(app)
    @app = app
  end

  def map(path, &block) = @app.map(path, &block)

  def intercept(&handler)
    @handler = handler
    before_next_spec { @handler = nil }
  end

  def call(env)
    if (handler = @handler)
      handler.call(env, @app)
    else
      @app.call(env)
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) { Capybara.app = SystemTestRequests.new(Capybara.app) }
end
