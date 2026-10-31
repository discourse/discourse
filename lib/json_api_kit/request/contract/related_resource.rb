# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      class RelatedResource < Contract
        include Fields
        include Including
        include Filtering
      end
    end
  end
end
