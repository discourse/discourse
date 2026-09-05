# frozen_string_literal: true

module JsonApiKit
  module Name
    Relationship =
      Data.define(:value, :type) do
        include Name

        def kind = :relationship
      end
  end
end
