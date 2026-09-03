# frozen_string_literal: true

module JsonApiKit
  module Name
    Anchor =
      Data.define(:value, :type) do
        include Name

        def kind = :anchor
      end
  end
end
