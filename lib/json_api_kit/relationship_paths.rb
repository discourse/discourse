# frozen_string_literal: true

module JsonApiKit
  class RelationshipPaths
    class UnknownPath < BadParameter
      def initialize(path, parameter: nil)
        @path = path
        super("There is no relationship path named #{path}.", parameter:)
      end

      def title = "No such relationship path"

      private

      attr_reader :path

      def arguments = [path]
    end

    def initialize(resource:, glossary:)
      @resource = resource
      @glossary = glossary
    end

    def declared_path(path)
      translate(path_names(path)) { |position, name| position.advance_to_declared(member: name) }
    rescue UnknownPath
      raise UnknownPath.new(path.to_s)
    end

    def member_path(path)
      translate(path_names(path)) { |position, name| position.advance_to_member(declared: name) }
    end

    private

    attr_reader :resource, :glossary

    def translate(names, &)
      return "" if names.empty?
      steps(names.each, &).map(&:name).join(Path::SEPARATOR)
    end

    def steps(names, &advance)
      Enumerator.produce(advance.call(position, names.next)) do |step|
        advance.call(step.next_position, names.next)
      end
    end

    def path_names(path) = path.to_s.split(Path::SEPARATOR, -1)

    def position = Position.new(resource:, glossary:)
  end
end
