# frozen_string_literal: true

module JsonApiKit
  class Urls
    def initialize(base:, current:, parameters: {})
      @base = base
      @current = current
      @parameters = parameters
    end

    def current = Url.new(@current, parameters)

    def record(type, id) = Url.new("#{base}/#{type}/#{id}")

    def relationship(type, id, name) = Url.new("#{record(type, id)}/relationships/#{name}")

    def related(type, id, name) = Url.new("#{record(type, id)}/#{name}")

    private

    attr_reader :base, :parameters
  end
end
