# frozen_string_literal: true

module JsonApiKit
  module Name
    Field = Data.define(:value, :type) { include Name }
  end
end
