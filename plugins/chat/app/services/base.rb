# frozen_string_literal: true

module Chat
  module Service
    module Base
      extend ActiveSupport::Concern

      # The only exception that can be raised by a service.
      class Failure < StandardError
        # @return [Context]
        attr_reader :context

        # @!visibility private
        def initialize(context = nil)
          @context = context
          super
        end
      end

      # Simple structure to hold the context of the service during its whole lifecycle.
      class Context < OpenStruct
        def success?
          !failure?
        end

        def failure?
          @failure || false
        end

        # Marks the service as failed.
        # @param context [Hash, Context] the context to merge into the current one
        # @example
        #   context.fail!("failure": "something went wrong")
        # @return [Context]
        def fail!(context = {})
          fail(context)
          raise Failure, self
        end

        # Marks the service as failed without raising an exception.
        # @param context [Hash, Context] the context to merge into the current one
        # @example
        #   context.fail("failure": "something went wrong")
        # @return [Context]
        def fail(context = {})
          merge(context)
          @failure = true
          self
        end

        # Merges the given context into the current one.
        # @!visibility private
        def merge(other_context = {})
          other_context.each { |key, value| self[key.to_sym] = value }
          self
        end

        private

        def self.build(context = {})
          self === context ? context : new(context)
        end
      end

      module StepsHelpers
        def model(name = :model, step_name = :"fetch_#{name}")
          steps << ModelStep.new(name, step_name)
        end

        def contract(name = :default, class_name: self::Contract)
          steps << ContractStep.new(name, class_name: class_name)
        end

        def policy(name = :default)
          steps << PolicyStep.new(name)
        end

        def step(name)
          steps << Step.new(name)
        end

        def transaction(&block)
          steps << TransactionStep.new(&block)
        end
      end

      class Step
        attr_reader :name, :method_name, :class_name

        def initialize(name, method_name = name, class_name: nil)
          @name = name
          @method_name = method_name
          @class_name = class_name
        end

        def call(instance, context)
          method = instance.method(method_name)
          args = {}
          args = context.to_h unless method.arity.zero?
          instance.instance_exec(**args, &method)
        end
      end

      class ModelStep < Step
        def call(instance, context)
          context[name] = super
          raise ArgumentError unless context[name]
        rescue ArgumentError
          context.fail!("result.#{name}": Context.build.fail)
        end
      end

      class PolicyStep < Step
        def call(instance, context)
          context.fail!("result.policy.#{name}": Context.build.fail) unless super
        end
      end

      class ContractStep < Step
        def call(instance, context)
          contract = class_name.new(context.to_h.slice(*class_name.attribute_names.map(&:to_sym)))
          context[:"contract.#{name}"] = contract

          unless contract.valid?
            context.fail!("result.contract.#{name}": Context.build.fail(errors: contract.errors))
          end
        end
      end

      class TransactionStep < Step
        include StepsHelpers

        attr_reader :steps

        def initialize(&block)
          @steps = []
          instance_exec(&block)
        end

        def call(instance, context)
          ActiveRecord::Base.transaction { steps.each { |step| step.call(instance, context) } }
        end
      end

      included do
        attr_reader :context

        # @!visibility private
        # Internal class used to setup the base contract of the service.
        self::Contract =
          Class.new do
            include ActiveModel::API
            include ActiveModel::Attributes
            include ActiveModel::AttributeMethods
          end
      end

      class_methods do
        include StepsHelpers

        def call(context = {})
          new(context).tap(&:run).context
        end

        def call!(context = {})
          new(context).tap(&:run!).context
        end

        def steps
          @steps ||= []
        end
      end

      # @!scope class
      # @!method policy(name = :default, &block)
      # Evaluates a set of conditions related to the given context. If the
      # block doesn’t return a truthy value, then the policy will fail.
      # More than one policy can be defined and named. When that’s the case,
      # policies are evaluated in their definition order.
      #
      # @example
      #   policy(:invalid_access) do
      #     guardian.can_delete_chat_channel?
      #   end

      # @!scope class
      # @!method contract(&block)
      # Checks the validity of the input parameters.
      # Implements ActiveModel::Validations and ActiveModel::Attributes.
      #
      # @example
      #   contract do
      #     attribute :name
      #     validates :name, presence: true
      #   end

      # @!scope class
      # @!method service(&block)
      # Holds the business logic of the service.
      #
      # @example
      #   service { context.topic.update!(archived: true) }

      # @!visibility private
      def initialize(initial_context = {})
        @initial_context = initial_context.with_indifferent_access
        @context = Context.build(initial_context)
      end

      private

      def run
        run!
      rescue Failure => exception
        raise if context.object_id != exception.context.object_id
      end

      def run!
        self.class.steps.each { |step| step.call(self, context) }
      end
    end
  end
end
