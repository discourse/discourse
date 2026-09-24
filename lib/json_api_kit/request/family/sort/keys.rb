# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Sort
        class Keys
          Key = Data.define(:name, :direction, :path)

          class << self
            def parse(value, path)
              case value
              when Hash
                new(
                  value.map { |name, direction| Key.new(name.to_s, direction, path + [name.to_s]) },
                  path,
                )
              when String, Symbol
                new(value.to_s.split(LIST, -1).map { key(it, path) }, path)
              end
            end

            private

            def key(item, path)
              prefix, name = LIST_ITEM.match(item).captures
              Key.new(name, SORT_DIRECTIONS[prefix], path)
            end
          end

          def initialize(keys, path)
            @keys = keys
            @path = path
          end

          def declare
            keys
              .group_by { yield(it) }
              .to_h { |declared, same_name| [declared, shared_direction(same_name)] }
          end

          private

          attr_reader :keys, :path

          def shared_direction(keys)
            raise TwoDirections.new(keys.map(&:name), parameter:) unless one_direction?(keys)
            keys.first.direction
          end

          def one_direction?(keys) = keys.map(&:direction).uniq(&:to_s).one?

          def parameter = ParameterName.new(*path).to_s
        end
      end
    end
  end
end
