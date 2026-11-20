# frozen_string_literal: true

module JsonApiKit
  module Name
    Anchor = Data.define(:value, :type) { include Name::ResourceScope }
  end
end
