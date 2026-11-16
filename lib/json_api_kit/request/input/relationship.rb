# frozen_string_literal: true

module JsonApiKit
  class Request
    class Input
      class Relationship < Collection
        private

        def contract_class = Contract::Relationship
      end
    end
  end
end
