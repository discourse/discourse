# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Including
        extend ActiveSupport::Concern

        class IncludeType < ActiveModel::Type::Value
          def cast_value(value)
            case value
            when String
              value.split(LIST)
            else
              value
            end
          end
        end

        included do
          attribute :include, IncludeType.new, default: -> { [] }

          validate :check_include_paths, if: -> { include.present? }
        end

        private

        def check_include_paths
          Paths
            .new(include)
            .reject { resource.paths_include?(it) }
            .each do |path|
              errors.add(
                :include,
                :no_such_name,
                path: relationship_paths.member_path(path),
                message: "no such name",
              )
            end
        end

        def relationship_paths = @relationship_paths ||= RelationshipPaths.new(resource:, glossary:)
      end
    end
  end
end
