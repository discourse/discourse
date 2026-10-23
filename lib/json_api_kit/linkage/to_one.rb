# frozen_string_literal: true

module JsonApiKit
  class Linkage
    class ToOne < Linkage
      def collapse(&) = records.first.try(&)
    end
  end
end
