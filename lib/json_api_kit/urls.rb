# frozen_string_literal: true

module JsonApiKit
  class Urls
    def initialize(base:, current:, parameters: {})
      @base = base
      @current = current
      @parameters = parameters
    end

    def current = Url.new(@current, parameters)

    def for(record) = RecordUrl.new(base, record)

    private

    attr_reader :base, :parameters
  end
end
