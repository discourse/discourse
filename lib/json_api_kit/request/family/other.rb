# frozen_string_literal: true

module JsonApiKit
  class Request
    class Family
      class Other < Family
        def declared_value(value, _path) = value
      end
    end
  end
end
