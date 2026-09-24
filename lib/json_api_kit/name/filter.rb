# frozen_string_literal: true

module JsonApiKit
  module Name
    Filter = Data.define(:value, :type) { include Name }
  end
end
