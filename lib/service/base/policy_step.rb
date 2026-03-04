# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class PolicyStep < Step
      def run_step
        if !super
          context[result_key].fail(reason: context[result_key].object&.reason)
          context.fail!
        end
      end
    end
  end
end
