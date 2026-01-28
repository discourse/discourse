# frozen_string_literal: true

module Migrations
  module Converters
    class Base
      class << self
        def inherited(subclass)
          super
          Registry.register(subclass)
        end
      end

      def run
        raise NotImplementedError, "Subclasses must implement #run"
      end
    end
  end
end
