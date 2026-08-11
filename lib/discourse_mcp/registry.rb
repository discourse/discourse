# frozen_string_literal: true

module DiscourseMcp
  class Registry
    def initialize
      @capabilities = {}
      @mutex = Mutex.new
    end

    def register(**attributes)
      capability = Capability.new(**attributes)
      key = [capability.kind, capability.identifier]
      @mutex.synchronize do
        if @capabilities.key?(key)
          raise ArgumentError, "MCP capability already registered: #{key.join(":")}"
        end

        @capabilities[key] = capability
      end
      capability
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
      @capabilities[[kind.to_sym, identifier.to_s]]
    end

    def all(kind = nil)
      values = @capabilities.values
      values = values.select { |capability| capability.kind == kind.to_sym } if kind
      values.sort_by(&:identifier)
    end

    def scopes
      all.flat_map(&:required_scopes).uniq.sort
    end
  end
end
