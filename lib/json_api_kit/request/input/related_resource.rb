# frozen_string_literal: true

module JsonApiKit
  class Request
    class Input
      class RelatedResource < Input
        private

        def contract_class = Contract::RelatedResource
      end
    end
  end
end
