# frozen_string_literal: true

module JsonApiKit
  class Adapter
    class Definition
      def self.required_owner_fields(_name, owner_resource:) = []

      def initialize(declarations)
        @declarations = declarations
      end

      def valid_cursor?(_raw) = false

      private

      attr_reader :declarations
    end
  end
end
