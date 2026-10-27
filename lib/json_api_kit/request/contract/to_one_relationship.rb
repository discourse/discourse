# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      class ToOneRelationship < Contract
        include Fields
        include Filtering
      end
    end
  end
end
