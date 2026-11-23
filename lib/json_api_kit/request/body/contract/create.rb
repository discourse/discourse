# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Contract
        class Create < Contract
          validate :check_id, if: :resource_object?

          private

          def check_id
            errors.add(:"data.id", :unsupported) if location(:"data.id").supplied?
          end
        end
      end
    end
  end
end
