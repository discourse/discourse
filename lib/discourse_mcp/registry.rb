# frozen_string_literal: true

module DiscourseMcp
  class Registry
    def initialize
      @primitives = {}
      @mutex = Mutex.new
    end

    def register(**attributes)
      primitive = Primitive.new(**attributes)
      key = [primitive.kind, primitive.identifier]
      @mutex.synchronize do
        if @primitives.key?(key)
          raise ArgumentError, "MCP primitive already registered: #{key.join(":")}"
        end

        @primitives[key] = primitive
      end
      primitive
    end

    def register_tool(identifier, **attributes)
      register(identifier: identifier, kind: :tool, **attributes)
    end

    def register_resource(identifier, **attributes)
      register(identifier: identifier, kind: :resource, **attributes)
    end

    def register_resource_template(identifier, **attributes)
      register(identifier: identifier, kind: :resource_template, **attributes)
    end

    def register_prompt(identifier, **attributes)
      register(identifier: identifier, kind: :prompt, **attributes)
    end

    def find(kind, identifier)
      @primitives[[kind.to_sym, identifier.to_s]]
    end

    def all(kind = nil)
      values = @primitives.values
      values = values.select { |primitive| primitive.kind == kind.to_sym } if kind
      values.sort_by(&:identifier)
    end

    def scopes
      all.flat_map(&:required_scopes).uniq.sort
    end
  end
end
