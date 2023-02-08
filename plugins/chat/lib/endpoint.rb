# frozen_string_literal: true
#
# = Chat::Endpoint
#
# This class is to be used via its helper +with_service+ in a controller. Its
# main purpose is to ease how actions can be run upon a service completion.
# Since a service will likely return the same kind of things over and over,
# this allows us to not have to repeat the same boilerplate code in every
# controller.
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
# @example
#   # in a controller
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
# The actions will be evaluated in the order they appear. So even if the
# service will ultimately fail with a failed policy, in this example only the
# +on_failed_policy+ action will be executed and not the +on_failure+ one.
# The only exception to this being +on_failure+ as it will always be executed
# last.
#
class Chat::Endpoint
  # @!visibility private
  NULL_RESULT = OpenStruct.new(failure?: false)
  # @!visibility private
  AVAILABLE_ACTIONS = {
    on_success: -> { result.success? },
    on_failure: -> { result.failure? },
    on_failed_policy: ->(name = "default") { failure_for?("result.policy.#{name}") },
    on_failed_contract: ->(name = "default") { failure_for?("result.contract.#{name}") },
    on_model_not_found: ->(name = "model") { failure_for?("result.#{name}") },
  }.with_indifferent_access.freeze

  # @!visibility private
  attr_reader :service, :controller

  delegate :result, to: :controller

  # @!visibility private
  def initialize(service, controller)
    @service = service
    @controller = controller
    @actions = {}
  end

  # @param service [Class] a class including {Chat::Service::Base}
  # @param block [Proc] a block containing the steps to match on
  # @return [void]
  def self.call(service, &block)
    controller = eval("self", block.binding, __FILE__, __LINE__)
    new(service, controller).call(&block)
  end

  # @!visibility private
  def call(&block)
    instance_eval(&block)
    controller.instance_eval("run_service(#{service})", __FILE__, __LINE__ - 1)
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
    (controller.result[key] || NULL_RESULT).failure?
  end

  def add_action(name, *args, &block)
    actions[[name, *args].join("_").to_sym] = [
      -> { instance_exec(*args, &AVAILABLE_ACTIONS[name]) },
      -> { controller.instance_eval(&block) },
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
