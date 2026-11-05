# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      class Relationship < Contract
        include Fields
        include Sorting
        include Filtering
        include Paging
      end
    end
  end
end
