# frozen_string_literal: true

module Service
  module Base
    class EachStep < Step
      include StepsHelpers

      attr_reader :steps, :item_name

      def initialize(name, as: nil, &block)
        super(name)
        @item_name = as || name.to_s.singularize.to_sym
        @steps = []
        instance_exec(&block)
      end

      def run_step
        return context[result_key][:skipped?] = true if collection.blank?

        collection.each_with_index do |item, index|
          context[item_name] = item
          context[:index] = index
          steps.each { |step| step.call(instance, context) }
        end
      end

      private

      def collection
        context[name]
      end
    end
  end
end
