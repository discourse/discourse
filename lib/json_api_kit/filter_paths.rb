# frozen_string_literal: true

module JsonApiKit
  class FilterPaths
    MAX_DEPTH = 32
    private_constant :MAX_DEPTH

    class TooDeep < BadParameter
      def initialize(parameter: nil)
        super("Filter paths cannot traverse more than #{MAX_DEPTH} relationships.", parameter:)
      end

      def title = "Filter path too deep"

      private

      def arguments = []
    end

    def initialize(resource:, glossary:, depth: 0)
      @resource = resource
      @glossary = glossary
      @depth = depth
    end

    def declared_path(member)
      local_path(member).then do |path|
        return path if path.declared? || !member.include?(".")
        related_path(member)
      end
    end

    private

    attr_reader :resource, :glossary, :depth

    def local_path(member)
      Path.new(relationships: [], filter: filter_name(member), resource:)
    end

    def filter_name(member)
      glossary.declared_name(
        Name::Filter.new(value: member, type: glossary.member_type(resource.type)),
      )
    end

    def related_path(member) = follow_relationship(*member.split(".", 2))

    def follow_relationship(member, remaining)
      relationship_name(member).then do |name|
        for_relationship(name.value).declared_path(remaining).prepend(name)
      end
    end

    def for_relationship(name)
      raise TooDeep if depth >= MAX_DEPTH
      self.class.new(resource: related_resource(name), glossary:, depth: depth + 1)
    end

    def relationship_name(member)
      Name::Relationship.new(
        value: glossary.declared_relationship(member:, type: resource.type),
        type: resource.type,
      )
    end

    def related_resource(name)
      resource.related_resource(name)
    rescue Resource::UnknownRelationship
      raise RelationshipPaths::UnknownPath.new(name)
    end
  end
end
