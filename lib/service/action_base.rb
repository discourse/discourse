# frozen_string_literal: true

class Service::ActionBase
  extend Dry::Initializer

  def self.call(...)
    new(...).call
  end

  def call
    raise NotImplementedError
  end
end
