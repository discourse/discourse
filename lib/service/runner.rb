# frozen_string_literal: true
#
# = Service::Runner
#
# This class is automatically used when passing a block to the `.call` method
# of a service. Its main purpose is to ease how actions can be run upon a
# service completion. Since a service will likely return the same kind of
# things over and over, this allows us to not have to repeat the same
# boilerplate code in every object.
#
# There are several available actions and we can add new ones very easily:
#
# * +on_success+: will execute the provided block if the service succeeds
# * +on_failure+: will execute the provided block if the service fails
# * +on_failed_step(name)+: will execute the provided block if the step named
#   `name` fails
# * +on_failed_policy(name)+: will execute the provided block if the policy
#   named `name` fails
# * +on_failed_contract(name)+: will execute the provided block if the contract
#   named `name` fails
# * +on_model_not_found(name)+: will execute the provided block if the model
#   named `name` is not present
# * +on_model_errors(name)+: will execute the provided block if the model named
#   `name` contains validation errors
#
# All the specialized steps receive the failing step result object as an
# argument to their block. `on_model_errors` receives the actual model so it’s
# easier to inspect it.
#
# @example In a controller
#   def create
#     MyService.call do
#       on_success do
#         flash[:notice] = "Success!"
#         redirect_to a_path
#       end
#       on_failed_policy(:a_named_policy) { |policy| redirect_to root_path, alert: policy.reason }
#       on_failure { render :new }
#     end
#   end
#
# @example In a job
#   def execute(*)
#     MyService.call(*) do
#       on_success { Rails.logger.info "SUCCESS" }
#       on_failure { Rails.logger.error "FAILURE" }
#     end
#   end
#
# The actions will be evaluated in the order they appear. So even if the
# service ultimately fails with a failed policy, in this example only the
# +on_failed_policy+ action will be executed and not the +on_failure+ one. The
# only exception to this being +on_failure+ as it will always be executed last.
#

class Service::Runner
  # @!visibility private
  AVAILABLE_ACTIONS = {
    on_success: {
      condition: -> { result.success? },
      key: [],
    },
    on_failure: {
      condition: -> { result.failure? },
      key: [],
    },
    on_failed_step: {
      condition: ->(name) { failure_for?("result.step.#{name}") },
      key: %w[result step],
    },
    on_failed_policy: {
      condition: ->(name = "default") { failure_for?("result.policy.#{name}") },
      key: %w[result policy],
      default_name: "default",
    },
    on_failed_contract: {
      condition: ->(name = "default") { failure_for?("result.contract.#{name}") },
      key: %w[result contract],
      default_name: "default",
    },
    on_model_not_found: {
      condition: ->(name = "model") do
        failure_for?("result.model.#{name}") && result["result.model.#{name}"].not_found
      end,
      key: %w[result model],
      default_name: "model",
    },
    on_model_errors: {
      condition: ->(name = "model") do
        failure_for?("result.model.#{name}") && result["result.model.#{name}"].invalid
      end,
      key: [],
      default_name: "model",
    },
  }.with_indifferent_access.freeze

  # @!visibility private
  attr_reader :service, :object, :dependencies

  # @!visibility private
  def initialize(service, object, dependencies)
    @service = service
    @object = object
    @dependencies = dependencies
    @actions = {}
  end

  # @param service [Class] a class including {Service::Base}
  # @param dependencies [Hash] dependencies to be provided to the service
  # @param block [Proc] a block containing the steps to match on
  # @return [void]
  def self.call(service, dependencies = {}, &block)
    new(service, block.binding.eval("self"), dependencies).call(&block)
  end

  # @!visibility private
  def call(&block)
    instance_exec(result, &block)
    # Always have `on_failure` as the last action
    (
      actions
        .except(:on_failure)
        .merge(actions.slice(:on_failure))
        .detect { |name, (condition, _)| condition.call } || [-> {}]
    ).flatten.last.call
  end

  private

  attr_reader :actions

  def result
    @result ||= service.call(dependencies)
  end

  def failure_for?(key)
    result[key]&.failure?
  end

  def add_action(name, *args, &block)
    action = AVAILABLE_ACTIONS[name]
    actions[[name, *args].join("_").to_sym] = [
      -> { instance_exec(*args, &action[:condition]) },
      -> do
        object.instance_exec(
          result[[*action[:key], args.first || action[:default_name]].join(".")],
          **result.slice(*block.parameters.filter_map { _1.last if _1.first == :keyreq }),
          &block
        )
      end,
    ]
  end

  def method_missing(method_name, *args, &block)
    return super unless AVAILABLE_ACTIONS[method_name]
    add_action(method_name, *args, &block)
  end

  def respond_to_missing?(method_name, include_private = false)
    AVAILABLE_ACTIONS[method_name] || super
  end
end
