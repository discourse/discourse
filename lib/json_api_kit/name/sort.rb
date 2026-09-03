# frozen_string_literal: true

module JsonApiKit
  module Name
    Sort =
      Data.define(:value, :type) do
        include Name

        def kind = :sort
      end
  end
end
