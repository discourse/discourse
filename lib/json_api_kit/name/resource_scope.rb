# frozen_string_literal: true

module JsonApiKit
  module Name
    module ResourceScope
      include Name

      def convert(&) = super.convert_type(&)

      def convert_type = with(type: yield(type))
    end
  end
end
