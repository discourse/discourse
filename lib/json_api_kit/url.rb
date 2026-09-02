# frozen_string_literal: true

module JsonApiKit
  class Url
    PAGE = "page"

    KIT = Glossary.kit
    REPLACED_MEMBERS =
      %w[after before anchor before_size after_size include_anchor]
        .map { KIT.member_name(it) }
        .freeze
        .freeze

    def initialize(address, parameters = {})
      @address = address
      @parameters = parameters
    end

    def at(**page)
      self.class.new(
        address,
        parameters.merge(
          PAGE => page_parameters.except(*REPLACED_MEMBERS).merge(member_names(page)),
        ),
      )
    end

    def to_s = "#{address}#{query_string}"

    private

    attr_reader :address, :parameters

    def page_parameters = parameters.fetch(PAGE, {})

    def member_names(page) = page.transform_keys { KIT.member_name(it) }

    def query_string = Rack::Utils.build_nested_query(parameters).presence.try { "?#{it}" }
  end
end
