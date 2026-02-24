# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class OptionsStep < Step
      def run_step
        context[:options] = class_name.new(context[:options])
      end
    end
  end
end
