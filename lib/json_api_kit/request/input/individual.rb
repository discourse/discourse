# frozen_string_literal: true

module JsonApiKit
  class Request
    class Input
      class Individual < Input
        private

        def contract_class = Contract::Individual
      end
    end
  end
end
