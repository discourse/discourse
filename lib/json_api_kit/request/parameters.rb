# frozen_string_literal: true

module JsonApiKit
  class Request
    class Parameters
      FAMILIES = {
        "fields" => Family::Fields,
        "sort" => Family::Sort,
        "filter" => Family::Filter,
        "page" => Family::Page,
        "include" => Family::Include,
      }.freeze

      def initialize(raw, glossary:, resource:)
        @raw = raw
        @glossary = glossary
        @resource = resource
      end

      def to_h
        raw.to_h do |family, value|
          key = declared_name(family)
          [key, family_for(key).declared_value(value, [key])]
        end
      end

      private

      attr_reader :raw, :glossary, :resource

      def family_for(key) = FAMILIES.fetch(key, Family::Other).new(glossary:, type: resource.type)

      def declared_name(family)
        glossary.declared_name(Name::Member.new(value: family)).value
      rescue Glossary::NotAMemberName => error
        raise error.at(ParameterName.new(family).to_s)
      end
    end
  end
end
