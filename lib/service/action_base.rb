# frozen_string_literal: true

class Service::ActionBase
  extend Dry::Initializer

  class << self
    def call(...)
      new(...).call
    end
  end

  def call
    raise NotImplementedError
  end
end
