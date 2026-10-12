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

    def initialize(guardian:, edition: Edition.current)
      @guardian = guardian
      @edition = edition
    end

    attr_reader :guardian, :edition
  end
end
