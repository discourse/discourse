# frozen_string_literal: true

module JsonApiKit
  class Request
    class Input
      class ToOneRelationship < Input
        private

        def contract_class = Contract::ToOneRelationship
      end
    end
  end
end
