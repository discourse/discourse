# frozen_string_literal: true

module JsonApiKit
  module Name
    Filter =
      Data.define(:value, :type) do
        include Name

        def kind = :filter
      end
  end
end
