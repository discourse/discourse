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
              value.split(",")
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
          refuse_unknown(
            :include,
            Paths
              .new(include)
              .reject { resource.paths_include?(it) }
              .map { Name::Member.new(value: it.to_s) },
          )
        end
      end
    end
  end
end
