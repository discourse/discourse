# frozen_string_literal: true

module JsonApiKit
  module Name
    Field =
      Data.define(:value, :type) do
        include Name

        def kind = :field
      end
  end
end
