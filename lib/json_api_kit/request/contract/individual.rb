# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      class Individual < Contract
        include Fields
        include Including
      end
    end
  end
end
