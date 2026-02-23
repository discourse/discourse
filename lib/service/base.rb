# frozen_string_literal: true

# @!parse
#   module Service::Base
#     # @!scope class
#     # @!method model(name = :model, step_name = :"fetch_#{name}", optional: false)
#     # @param name [Symbol] name of the model
#     # @param step_name [Symbol] name of the method to call for this step
#     # @param optional [Boolean] if +true+, then the step won't fail if its return value is falsy.
#     # Evaluates arbitrary code to build or fetch a model (typically from the
#     # DB). If the step returns a falsy value, then the step will fail.
#     #
#     # It stores the resulting model in +context[:model]+ by default (can be
#     # customized by providing the +name+ argument).
#     #
#     # @example
#     #   model :channel
#     #
#     #   private
#     #
#     #   def fetch_channel(channel_id:)
#     #     Chat::Channel.find_by(id: channel_id)
#     #   end
#
#     # @!scope class
#     # @!method policy(name = :default, class_name: nil)
#     # @param name [Symbol] name for this policy
#     # @param class_name [Class] a policy object (should inherit from +PolicyBase+)
#     # Performs checks related to the state of the system. If the
#     # step doesn't return a truthy value, then the policy will fail.
#     #
#     # When using a policy object, there is no need to define a method on the
#     # service for the policy step. The policy object `#call` method will be
#     # called and if the result isn't truthy, a `#reason` method is expected to
#     # be implemented to explain the failure.
#     #
#     # Policy objects are usually useful for more complex logic.
#     #
#     # @example Without a policy object
#     #   policy :no_direct_message_channel
#     #
#     #   private
#     #
#     #   def no_direct_message_channel(channel:)
#     #     !channel.direct_message_channel?
#     #   end
#     #
#     # @example With a policy object
#     #   # in the service object
#     #   policy :no_direct_message_channel, class_name: NoDirectMessageChannelPolicy
#     #
#     #   # in the policy object File
#     #   class NoDirectMessageChannelPolicy < PolicyBase
#     #     def call
#     #       !context.channel.direct_message_channel?
#     #     end
#     #
#     #     def reason
#     #       "Direct message channels aren't supported"
#     #     end
#     #   end
#
#     # @!scope class
#     # @!method params(name = :default, default_values_from: nil, &block)
#     # @param name [Symbol] name for this contract
#     # @param default_values_from [Symbol] name of the model to get default values from
#     # @param block [Proc] a block containing validations
#     # Checks the validity of the input parameters.
#     # Implements ActiveModel::Validations and ActiveModel::Attributes.
#     #
#     # It stores the resulting contract in +context[:params]+ by default
#     # (can be customized by providing the +name+ argument).
#     #
#     # @example
#     #   params do
#     #     attribute :name
#     #     validates :name, presence: true
#     #   end
#
#     # @!scope class
#     # @!method step(name)
#     # @param name [Symbol] the name of this step
#     # Runs arbitrary code. To mark a step as failed, a call to {#fail!} needs
#     # to be made explicitly.
#     #
#     # @example
#     #   step :update_channel
#     #
#     #   private
#     #
#     #   def update_channel(channel:, params_to_edit:)
#     #     channel.update!(params_to_edit)
#     #   end
#     # @example using {#fail!} in a step
#     #   step :save_channel
#     #
#     #   private
#     #
#     #   def save_channel(channel:)
#     #     fail!("something went wrong") if !channel.save
#     #   end
#
#     # @!scope class
#     # @!method transaction(&block)
#     # @param block [Proc] a block containing steps to be run inside a transaction
#     # Runs steps inside a DB transaction.
#     #
#     # @example
#     #   transaction do
#     #     step :prevents_slug_collision
#     #     step :soft_delete_channel
#     #     step :log_channel_deletion
#     #   end
#
#     # @!scope class
#     # @!method options(&block)
#     # @param block [Proc] a block containing options definition
#     # This is used to define options allowing to parameterize the service
#     # behavior. The resulting options are available in `context[:options]`.
#     #
#     # @example
#     #   options do
#     #     attribute :my_option, :boolean, default: false
#     #   end
#
#     # @!scope class
#     # @!method try(*exceptions, &block)
#     # @param exceptions [Array<Class>] one or more exception classes to catch (defaults to +StandardError+)
#     # @param block [Proc] a block containing steps to be wrapped
#     # Wraps steps and catches specified exceptions. If any wrapped step
#     # raises a matching exception, the step fails and the execution flow
#     # is halted. The caught exception is available on the result object.
#     #
#     # @example
#     #   try do
#     #     step :risky_operation
#     #   end
#     #
#     # @example catching specific exceptions
#     #   try(ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid) do
#     #     step :save_record
#     #   end
#
#     # @!scope class
#     # @!method lock(*keys, &block)
#     # @param keys [Array<Symbol>] one or more keys to build a unique lock name
#     # @param block [Proc] a block containing steps to be wrapped
#     # Wraps steps inside a +DistributedMutex+. Keys are resolved from
#     # +params+ first, then from the service context. When a resolved value
#     # responds to +id+ (e.g. an ActiveRecord model), its +id+ is used
#     # automatically. Fails if the lock cannot be acquired.
#     #
#     # @example locking on a param
#     #   lock(:user_id) do
#     #     step :update_user
#     #   end
#     #
#     # @example locking on a model from context
#     #   model :topic
#     #   lock(:topic) do
#     #     step :update_topic
#     #   end
#
#     # @!scope class
#     # @!method only_if(name, &block)
#     # @param name [Symbol] the name of the condition to check
#     # @param block [Proc] a block containing steps to conditionally run
#     # Conditionally runs the steps in its block. If the condition method
#     # returns a falsy value, the steps are skipped but the execution flow
#     # is not halted.
#     #
#     # @example
#     #   only_if(:has_post) do
#     #     step :update_post
#     #     step :log_post_update
#     #   end
#   end

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

    included do
      # The global context which is available from any step.
      attr_reader :context
    end

    class_methods do
      include StepsHelpers

      def call(context = {}, &actions)
        return new(context).tap(&:run).context unless block_given?
        Service::Runner.call(self, context, &actions)
      end

      def call!(context = {})
        new(context).tap(&:run!).context
      end

      def steps
        @steps ||= []
      end
    end

    # @!visibility private
    def initialize(initial_context = {})
      @context =
        Context.build(
          initial_context
            .compact
            .reverse_merge(params: {})
            .merge(__steps__: self.class.steps, __service_class__: self.class),
        )
      initialize_params
    end

    # @!visibility private
    def run
      run!
    rescue Failure => exception
      raise if context.object_id != exception.context.object_id
    end

    # @!visibility private
    def run!
      self.class.steps.each { |step| step.call(self, context) }
    end

    # @!visibility private
    def fail!(message)
      step_name = caller_locations(1, 1)[0].base_label
      context["result.step.#{step_name}"].fail(error: message)
      context.fail!
    end

    private

    def initialize_params
      klass =
        Data.define(*context[:params].keys) do
          alias to_hash to_h

          delegate :slice, :merge, to: :to_h

          def method_missing(*)
            nil
          end
        end
      context[:params] = klass.new(*context[:params].values)
    end
  end
end
