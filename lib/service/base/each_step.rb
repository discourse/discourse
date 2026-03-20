# frozen_string_literal: true

module Service
  module Base
    class EachStep < Step
      include StepsHelpers

      attr_reader :steps, :item_name, :persist

      def initialize(name, as: nil, persist: nil, &block)
        super(name)
        @item_name = as || name.to_s.singularize.to_sym
        @persist = normalize_persist(persist)
        @steps = []
        instance_exec(&block)
      end

      def run_step
        snapshot = context.to_h.deep_dup
        initialize_persisted_keys

        Array
          .wrap(context[name])
          .each_with_index do |item, index|
            context[item_name] = item
            context[:index] = index
            steps.each { |step| step.call(instance, context) }
          end

        restore_context(snapshot)
      end

      private

      def normalize_persist(persist)
        case persist
        when nil
          {}
        when Array
          persist.each_with_object({}) do |item, hash|
            case item
            when Symbol
              hash[item] = nil
            when Hash
              hash.merge!(item)
            end
          end
        when Hash
          persist
        end
      end

      def initialize_persisted_keys
        persist.each { |key, initializer| context[key] = resolve_initializer(initializer) }
      end

      def resolve_initializer(initializer)
        case initializer
        when Proc
          initializer.call
        when Symbol
          instance.send(initializer)
        when nil
          nil
        end
      end

      def restore_context(snapshot)
        persisted_values = persist.keys.to_h { |key| [key, context[key]] }

        # Remove keys added during iteration
        (context.to_h.keys - snapshot.keys).each { |key| context[key] = nil }

        # Restore original values
        snapshot.each { |key, value| context[key] = value }

        # Re-apply persisted values
        persisted_values.each { |key, value| context[key] = value }
      end
    end
  end
end
