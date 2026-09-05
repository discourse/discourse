# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      LIST = ","
      LIST_ITEM = /\A(?<direction>-?)(?<name>.*)\z/m

      def initialize(glossary:, type:)
        @glossary = glossary
        @type = type
      end

      private

      attr_reader :glossary, :type

      def names(value, path, &name_for)
        case value
        when Hash
          value.transform_keys { declared_name(name_for.call(it), path + [it]) }
        when Array
          value.map { names(it, path, &name_for) }
        when String, Symbol
          value.to_s.split(LIST, -1).map { list_item(it, path, &name_for) }.join(LIST)
        else
          value
        end
      end

      def list_item(value, path)
        direction, name = LIST_ITEM.match(value).captures
        "#{direction}#{declared_name(yield(name), path)}"
      end

      def declared_name(name, path)
        glossary.declared_name(name).value
      rescue Glossary::NotAMemberName => error
        raise error.at(ParameterName.new(*path).to_s)
      end
    end
  end
end
