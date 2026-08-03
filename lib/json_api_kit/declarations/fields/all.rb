# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Fields
      class All < Fields
        def initialize(**declarations) = super(nil, **declarations)

        def columns = Columns.all

        private

        def pick(fields) = fields
      end
    end
  end
end
