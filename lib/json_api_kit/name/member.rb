# frozen_string_literal: true

module JsonApiKit
  module Name
    Member = Data.define(:value) { include Name }
  end
end
