# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      class Collection < Contract
        include Fields
        include Including
        include Sorting
        include Filtering
        include Anchoring
        include Paging
      end
    end
  end
end
