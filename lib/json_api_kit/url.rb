# frozen_string_literal: true

module JsonApiKit
  class Url
    PAGE = "page"

    ENDS = %w[after before].freeze
    WINDOW = %w[anchor before_size after_size include_anchor].freeze

    def initialize(address, parameters = {})
      @address = address
      @parameters = parameters
    end

    def at(**page)
      self.class.new(
        address,
        parameters.merge(
          PAGE => page_parameters.except(*ENDS, *WINDOW).merge(page.transform_keys(&:to_s)),
        ),
      )
    end

    def to_s = "#{address}#{query_string}"

    private

    attr_reader :address, :parameters

    def page_parameters = parameters.fetch(PAGE, {})

    def query_string = parameters.to_query.presence&.then { "?#{it}" }
  end
end
