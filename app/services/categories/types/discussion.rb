# frozen_string_literal: true

module Categories
  module Types
    class Discussion < Base
      class << self
        def icon
          "comments"
        end
      end
    end
  end
end
