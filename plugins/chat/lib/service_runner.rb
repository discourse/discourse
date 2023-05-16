# frozen_string_literal: true
#
# = ServiceRunner
#
# This class is to be used via its helper +with_service+ in any class. Its
# main purpose is to ease how actions can be run upon a service completion.
# Since a service will likely return the same kind of things over and over,
# this allows us to not have to repeat the same boilerplate code in every
# object.
#
# There are several available actions and we can add new ones very easily:
#
# * +on_success+: will execute the provided block if the service succeeds
# * +on_failure+: will execute the provided block if the service fails
# * +on_failed_policy(name)+: will execute the provided block if the policy
#   named `name` fails
# * +on_failed_contract(name)+: will execute the provided block if the contract
#   named `name` fails
# * +on_model_not_found(name)+: will execute the provided block if the service
#   fails and its model is not present
#
# Default actions for each of these are defined in [Chat::ApiController#default_actions_for_service]
#
# @example In a controller
#   def create
#     with_service MyService do
#       on_success do
#         flash[:notice] = "Success!"
#         redirect_to a_path
#       end
#       on_failed_policy(:a_named_policy) { redirect_to root_path }
#       on_failure { render :new }
#     end
#   end
#
# @example In a job (inheriting from +ServiceJob+)
#   def execute(args = {})
#     with_service(MyService, **args) do
#       on_success { Rails.logger.info "SUCCESS" }
#       on_failure { Rails.logger.error "FAILURE" }
#     end
#   end
#
# The actions will be evaluated in the order they appear. So even if the
# service will ultimately fail with a failed policy, in this example only the
# +on_failed_policy+ action will be executed and not the +on_failure+ one.
# The only exception to this being +on_failure+ as it will always be executed
# last.
#

class ServiceRunner
  # @!visibility private
  NULL_RESULT = OpenStruct.new(failure?: false)
  # @!visibility private
  AVAILABLE_ACTIONS = {
    on_success: -> { result.success? },
    on_failure: -> { result.failure? },
    on_failed_step: ->(name) { failure_for?("result.step.#{name}") },
    on_failed_policy: ->(name = "default") { failure_for?("result.policy.#{name}") },
    on_failed_contract: ->(name = "default") { failure_for?("result.contract.#{name}") },
    on_model_not_found: ->(name = "model") do
      failure_for?("result.model.#{name}") && result[name].blank?
    end,
    on_model_errors: ->(name = "model") do
      failure_for?("result.model.#{name}") && result["result.model.#{name}"].invalid
    end,
  }.with_indifferent_access.freeze

  # @!visibility private
  attr_reader :service, :object, :dependencies

  delegate :result, to: :object

  # @!visibility private
  def initialize(service, object, **dependencies)
    @service = service
    @object = object
    @dependencies = dependencies
    @actions = {}
  end

  # @param service [Class] a class including {Service::Base}
  # @param block [Proc] a block containing the steps to match on
  # @return [void]
  def self.call(service, object, **dependencies, &block)
    new(service, object, **dependencies).call(&block)
  end

  # @!visibility private
  def call(&block)
    instance_eval(&block)
    object.run_service(service, dependencies)
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

  def failure_for?(key)
    (object.result[key] || NULL_RESULT).failure?
  end

  def add_action(name, *args, &block)
    actions[[name, *args].join("_").to_sym] = [
      -> { instance_exec(*args, &AVAILABLE_ACTIONS[name]) },
      -> { object.instance_eval(&block) },
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
