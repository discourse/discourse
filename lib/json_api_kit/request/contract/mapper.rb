# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      class Mapper
        MAX_SIZE = "https://jsonapi.org/profiles/ethanresnick/cursor-pagination/max-size-exceeded"
        RANGE_UNSUPPORTED =
          "https://jsonapi.org/profiles/ethanresnick/cursor-pagination/range-pagination-not-supported"
        NOT_AN_INTEGER = {
          title: "Page size is not an integer",
          detail: ->(_) { "Page size must be an integer." },
        }.freeze
        RANGE = {
          title: "Range pagination is not supported",
          detail: ->(_) { "Use page[after] or page[before], not both." },
          type: RANGE_UNSUPPORTED,
        }.freeze
        INVALID_CURSOR = {
          title: "Invalid cursor",
          detail: ->(_) { "Use a cursor from this API." },
        }.freeze
        SIDE_NOT_AN_INTEGER = {
          title: "Window size is not an integer",
          detail: ->(error) { "#{error.parameter} must be an integer." },
        }.freeze
        NEGATIVE_SIDE = {
          title: "Window size is negative",
          detail: ->(error) { "#{error.parameter} must be 0 or greater." },
        }.freeze
        CURSOR_NOT_THE_SORT = {
          title: "Cursor does not match the sort",
          detail: ->(_) { "This cursor comes from a different sort." },
        }.freeze
        WINDOW_PARAMETER = ->(error) { error.base.page.window_names.first }
        UNKNOWN_PARAMETER = {
          title: "No such parameter",
          detail: ->(error) { "There is no parameter named #{error.parameter}." },
        }.freeze

        RULES = {
          %i[anchor wrong_length] => {
            title: "Too many anchors",
            detail: ->(error) do
              "Use one anchor only. This request has #{error.base.anchor.size}."
            end,
          },
          %i[anchor present] => {
            title: "Anchor and cursor cannot be combined",
            detail: ->(error) { "Use anchor or page[#{error.base.page.cursor_name}], not both." },
          },
          %i[anchor blank] => {
            title: "Anchor is required",
            detail: ->(error) { "#{error.base.page.window_names.join(", ")} need an anchor." },
          },
          %i[anchor no_such_name] => {
            title: "No such anchor",
            detail: ->(error) { "There is no anchor named #{error.options[:name]}." },
            source: ->(error) { "anchor[#{error.options[:name]}]" },
          },
          %i[anchor not_the_sort] => {
            title: "Anchor does not match the sort",
            detail: ->(error) do
              "The anchor is #{error.options[:name]}, but this request sorts by " \
                "#{error.options[:key]}."
            end,
            source: ->(error) { "anchor[#{error.options[:name]}]" },
          },
          %i[sort no_such_name] => {
            title: "No such sort",
            detail: ->(error) { "There is no sort named #{error.options[:name]}." },
          },
          %i[sort unknown_direction] => {
            title: "No such sort direction",
            detail: ->(error) { "Sort direction #{error.options[:direction]} is not asc or desc." },
          },
          %i[filter no_such_name] => {
            title: "No such filter",
            detail: ->(error) { "There is no filter named #{error.options[:name]}." },
            source: ->(error) { "filter[#{error.options[:name]}]" },
          },
          %i[include no_such_name] => {
            title: "No such relationship path",
            detail: ->(error) { "There is no relationship path named #{error.options[:name]}." },
          },
          %i[fields bad_shape] => {
            title: "Invalid fields parameter",
            detail: ->(_) { "fields must name a list of fields for each type." },
          },
          %i[fields bad_value] => {
            title: "Invalid fields value",
            detail: ->(error) { "fields[#{error.options[:name]}] must be a list of field names." },
            source: ->(error) { "fields[#{error.options[:name]}]" },
          },
          %i[sort bad_shape] => {
            title: "Invalid sort parameter",
            detail: ->(_) { "sort must name a direction for each sort." },
          },
          %i[filter bad_shape] => {
            title: "Invalid filter parameter",
            detail: ->(_) { "filter must name a value for each filter." },
          },
          %i[filter bad_value] => {
            title: "Invalid filter value",
            detail: ->(error) do
              "filter[#{error.options[:name]}] must be a value or a list of values."
            end,
            source: ->(error) { "filter[#{error.options[:name]}]" },
          },
          %i[anchor bad_value] => {
            title: "Invalid anchor value",
            detail: ->(error) { "anchor[#{error.options[:name]}] must be a single value." },
            source: ->(error) { "anchor[#{error.options[:name]}]" },
          },
          %i[page bad_shape] => {
            title: "Invalid page parameter",
            detail: ->(_) { "page must name page parameters, as in page[size]=2." },
          },
          [:"page.size", :not_an_integer] => NOT_AN_INTEGER,
          [:"page.size", :not_a_number] => NOT_AN_INTEGER,
          [:"page.size", :greater_than] => {
            title: "Page size is too small",
            detail: ->(_) { "Page size must be at least 1." },
          },
          [:"page.size", :less_than_or_equal_to] => {
            title: "Page size is too large",
            detail: ->(error) do
              "Page size #{error.options[:value]} exceeds the maximum of #{error.options[:count]}."
            end,
            type: MAX_SIZE,
            meta: ->(error) { { page: { maxSize: error.options[:count] } } },
          },
          [:"page.before_size", :not_an_integer] => SIDE_NOT_AN_INTEGER,
          [:"page.before_size", :not_a_number] => SIDE_NOT_AN_INTEGER,
          [:"page.before_size", :greater_than_or_equal_to] => NEGATIVE_SIDE,
          [:"page.after_size", :not_an_integer] => SIDE_NOT_AN_INTEGER,
          [:"page.after_size", :not_a_number] => SIDE_NOT_AN_INTEGER,
          [:"page.after_size", :greater_than_or_equal_to] => NEGATIVE_SIDE,
          [:"page.window_size", :greater_than] => {
            title: "Window is empty",
            detail: ->(_) { "A window must be at least 1 row." },
            source: WINDOW_PARAMETER,
          },
          [:"page.window_size", :less_than_or_equal_to] => {
            title: "Window is too large",
            detail: ->(error) do
              "A window of #{error.options[:value]} rows exceeds " \
                "the maximum of #{error.options[:count]}."
            end,
            source: WINDOW_PARAMETER,
            type: MAX_SIZE,
            meta: ->(error) { { page: { maxSize: error.options[:count] } } },
          },
          [:"page.after", :present] => RANGE,
          [:"page.before", :present] => RANGE,
          [:"page.after", :unreadable_cursor] => INVALID_CURSOR,
          [:"page.before", :unreadable_cursor] => INVALID_CURSOR,
          [:"page.after", :not_the_sort] => CURSOR_NOT_THE_SORT,
          [:"page.before", :not_the_sort] => CURSOR_NOT_THE_SORT,
        }.freeze

        def initialize(errors)
          @errors = errors
        end

        def to_a = errors.map { Error.new(it, **rule_for(it)) }

        private

        attr_reader :errors

        def rule_for(error) = RULES.fetch([error.attribute, error.type], UNKNOWN_PARAMETER)
      end
    end
  end
end
