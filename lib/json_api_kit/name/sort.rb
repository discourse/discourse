# frozen_string_literal: true

module JsonApiKit
  module Name
    Sort = Data.define(:value, :type) { include Name }
  end
end
