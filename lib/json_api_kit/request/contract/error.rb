# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      class Error < BadRequest
        def initialize(error, glossary:, title:, detail: nil, source: nil, type: nil, meta: nil)
          @error = error
          @glossary = glossary
          @title = title
          @detail = detail
          @source = source
          @type = type
          @meta = meta
          super()
        end

        attr_reader :title, :type

        delegate :options, :base, to: :error

        def detail = @detail&.call(self) || error.message

        def source = { parameter: (@source&.call(self) || parameter).to_s }

        def meta = @meta&.call(self) || {}

        def parameter
          ParameterName.new(*error.attribute.to_s.split(".").map { member_value(member(it)) })
        end

        def name = member_value(options[:name])

        def key = member_value(options[:key])

        def member_parameter(member = name) = parameter.member(member)

        def window_parameters = base.page.window_names.map { page_parameter(it) }

        def cursor_parameter = page_parameter(base.page.cursor_name)

        def anchor_count = base.page.anchor.size

        private

        attr_reader :error, :glossary

        def member_value(name) = glossary.member_name(name).value

        def member(value) = Name::Member.new(value: value.to_s)

        def page_parameter(name) = parameter.family.member(member_value(member(name)))
      end
    end
  end
end
