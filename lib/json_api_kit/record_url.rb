# frozen_string_literal: true

module JsonApiKit
  class RecordUrl
    def initialize(base, record)
      @base = base
      @record = record
    end

    def to_s = address

    def relationship(name, parameters: {}) =
      Url.new("#{address}/relationships/#{path_segment(name)}", parameters)

    def related(name, parameters: {}) = Url.new("#{address}/#{path_segment(name)}", parameters)

    private

    attr_reader :base, :record

    def path_segment(name) = name.dasherize

    def address = [base, record.namespace, record.type, record.id].compact.join("/")
  end
end
