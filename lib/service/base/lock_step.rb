# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class LockStep < Step
      include StepsHelpers

      attr_reader :steps, :keys

      def initialize(*keys, &block)
        super(keys.join(":"))
        @keys = keys
        @steps = []
        instance_exec(&block)
      end

      def run_step
        success =
          begin
            DistributedMutex.synchronize(lock_name) do
              steps.each { |step| step.call(instance, context) }
              :success
            end
          rescue Discourse::ReadOnly
            :read_only
          end

        if success != :success
          context[result_key].fail(lock_not_acquired: true)
          context.fail!
        end
      end

      private

      def lock_name
        [
          context.__service_class__.to_s.underscore,
          *keys.flat_map do |key|
            value = context[:params].try(key) || context[key]
            [key, value.try(:id) || value]
          end,
        ].join(":")
      end
    end
  end
end
