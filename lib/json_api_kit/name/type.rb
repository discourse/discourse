# frozen_string_literal: true

module JsonApiKit
  module Name
    Type =
      Data.define(:value) do
        include Name

        def convert_type(&) = convert(&)
      end
  end
end
