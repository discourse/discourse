# frozen_string_literal: true

module JsonApiKit
  class Request
    class Input
      class Collection < Input
        private

        def contract_class = Contract::Collection

        def contract_parameters
          self.class.with_defaults(super, resource:, default_sorts:)
        end
      end
    end
  end
end
