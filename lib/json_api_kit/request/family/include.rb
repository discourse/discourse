# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Include < Family
        def declared_value(value, path) = names(value, path) { Name::Member.new(value: it) }
      end
    end
  end
end
