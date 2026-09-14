# frozen_string_literal: true

module JsonApiKit
  class BadParameter < BadRequest
    def initialize(message, parameter: nil)
      @parameter = parameter
      super(message)
    end

    def source = { parameter: }.compact

    def at(parameter) = self.class.new(*arguments, parameter:)

    private

    attr_reader :parameter
  end
end
