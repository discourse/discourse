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
        context.with_isolation(persist_keys: [item_name, :index, *persist.keys]) do
          persist.each { |key, initializer| context[key] = instance.instance_exec(&initializer) }

          Array
            .wrap(context[name])
            .each_with_index do |item, index|
              context[item_name] = item
              context[:index] = index
              steps.each { |step| step.call(instance, context) }
            end
        end
      end

      private

      def normalize_persist(persist)
        case persist
        when nil
          {}
        when Array
          persist.each_with_object({}) { |item, hash| hash.merge!(normalize_persist(item)) }
        when Symbol
          { persist => proc {} }
        when Hash
          persist.transform_values do |v|
            case v
            when Symbol
              proc { send(v) }
            when Proc
              proc { instance_exec(&v) }
            when nil
              proc {}
            end
          end
        end
      end
    end
  end
end
