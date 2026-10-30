# frozen_string_literal: true

module Service
  class ResourceImport
    class Relationship < Field
      delegate :parameter_name, to: :declaration

      def type = declaration.parameter_type

      def apply_to(contract)
        super
        contract.validates_with IdentifierValidator, attributes: [parameter_name]
        parameter_name.then do |parameter|
          contract.define_method("#{name}_provided?") { provided?(parameter) }
        end
      end
    end
  end
end
