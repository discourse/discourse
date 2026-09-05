# frozen_string_literal: true

module JsonApiKit
  module Name
    Member =
      Data.define(:value) do
        include Name

        def kind = :member
      end
  end
end
