# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Filter < Family
        def declared_value(value, path)
          return value unless value.is_a?(Hash)
          value.transform_keys do |name|
            filter_paths.declared_path(name)
          rescue Glossary::NotAMemberName,
                 RelationshipPaths::UnknownPath,
                 FilterPaths::TooDeep => error
            raise error.at(ParameterName.new(*path, name).to_s)
          end
        end

        private

        def filter_paths = @filter_paths ||= FilterPaths.new(resource:, glossary:)
      end
    end
  end
end
