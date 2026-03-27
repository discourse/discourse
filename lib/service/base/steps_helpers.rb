# frozen_string_literal: true

module Service
  module Base
    # Internal module to define available steps as DSL
    # @!visibility private
    module StepsHelpers
      def model(name = :model, step_name = :"fetch_#{name}", optional: false)
        steps << ModelStep.new(name, step_name, optional:)
      end

      def params(
        name = :default,
        default_values_from: nil,
        base_class: Service::ContractBase,
        &block
      )
        contract_class = Class.new(base_class).tap { it.class_eval(&block) if block }
        const_set("#{name.to_s.classify.sub("Default", "")}Contract", contract_class)
        steps << ContractStep.new(name, class_name: contract_class, default_values_from:)
      end

      def policy(name = :default, class_name: nil)
        steps << PolicyStep.new(name, class_name:)
      end

      def step(name)
        steps << Step.new(name)
      end

      def transaction(&block)
        steps << TransactionStep.new(&block)
      end

      def lock(*keys, &block)
        steps << LockStep.new(*keys, &block)
      end

      def options(&block)
        klass = Class.new(Service::OptionsBase).tap { it.class_eval(&block) }
        const_set("Options", klass)
        steps << OptionsStep.new(:default, class_name: klass)
      end

      def try(*exceptions, &block)
        steps << TryStep.new(exceptions, &block)
      end

      def only_if(name, &block)
        steps << OnlyIfStep.new(name, &block)
      end

      def each(collection_name, as: nil, persist: nil, &block)
        steps << EachStep.new(collection_name, as:, persist:, &block)
      end

      def reduce(collection_name, into:, initial: -> { {} }, as: nil, &block)
        each(collection_name, as:, persist: { into => initial }, &block)
      end
    end
  end
end
