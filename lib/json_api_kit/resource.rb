# frozen_string_literal: true

module JsonApiKit
  class Resource
    include Naming
    include Sorting
    include Filtering
    include Paging
    include Anchoring
    include Fields
    include Including
    include QueryInterface
  end
end
