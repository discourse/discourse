# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Include < Family
        def declared_value(value, path)
          case value
          when Array
            value.map { declared_value(it, path) }
          when String, Symbol
            value.to_s.split(LIST, -1).map { relationship_paths.declared_path(it) }.join(LIST)
          else
            value
          end
        rescue Glossary::NotAMemberName, RelationshipPaths::UnknownPath => error
          raise error.at(ParameterName.new(*path).to_s)
        end

        private

        def relationship_paths = @relationship_paths ||= RelationshipPaths.new(resource:, glossary:)
      end
    end
  end
end
