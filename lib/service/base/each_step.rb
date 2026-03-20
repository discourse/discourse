# frozen_string_literal: true

module Service
  module Base
    class EachStep < Step
      include StepsHelpers

      attr_reader :steps, :item_name, :initializers

      def initialize(name, as: nil, persist: nil, &block)
        super(name)
        @item_name = as || name.to_s.singularize.to_sym
        @initializers = build_initializers(persist)
        @steps = []
        instance_exec(&block)
      end

      def run_step
        context.with_isolation(persist_keys: [item_name, :index, *initializers.keys]) do
          context.merge!(initializers.transform_values { instance.instance_exec(&it) })

          Array
            .wrap(context[name])
            .each_with_index do |item, index|
              context.merge!(item_name => item, :index => index)
              steps.each { |step| step.call(instance, context) }
            end
        end
      end

      private

      def build_initializers(value)
        case value
        when nil
          {}
        when Array
          value.each_with_object({}) { |item, hash| hash.merge!(build_initializers(item)) }
        when Symbol
          { value => proc {} }
        when Hash
          value.transform_values(&method(:make_lambda))
        end
      end

      def make_lambda(filter)
        case filter
        when Symbol
          proc { send(filter) }
        when Proc
          proc { instance_exec(&filter) }
        else
          proc {}
        end
      end
    end
  end
end
