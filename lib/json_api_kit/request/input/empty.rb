# frozen_string_literal: true

module JsonApiKit
  class Request
    class Input
      class Empty < Input
        private

        def contract_class = Contract
      end
    end
  end
end
