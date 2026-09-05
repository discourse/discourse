# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Sort < Family
        def declared_value(value, path) = names(value, path) { Name::Sort.new(value: it, type:) }
      end
    end
  end
end
