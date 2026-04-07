# frozen_string_literal: true

module DiscourseWorkflows
  class NodeExecutionContext
    attr_reader :input_items,
                :node_context,
                :user,
                :run_as_user,
                :resolver,
                :vars,
                :expression_errors,
                :condition_details,
                :resolved_config

    def initialize(
      input_items:,
      node_context: {},
      user: nil,
      run_as_user: Discourse.system_user,
      resolver: nil,
      vars: nil
    )
      @input_items = input_items
      @node_context = node_context
      @user = user
      @run_as_user = run_as_user
      @resolver = resolver
      @vars = vars
      @expression_errors = []
      @condition_details = []
      @resolved_config = nil
    end

    def with_item(item)
      resolver.with_item(item["json"]) { yield }
    end

    def resolve_config(configuration)
      resolved = resolver.resolve_hash(configuration)
      @resolved_config ||= resolved
      resolved
    end

    def evaluate_filter(configuration)
      conditions = configuration.fetch("conditions") { [] }
      combinator = configuration.fetch("combinator") { "and" }
      options = configuration.fetch("options") { {} }
      result = FilterParameter.execute_filter(conditions, combinator, options, resolver)
      @condition_details.concat(result["details"]) if @condition_details.empty?
      result["passed"]
    end

    def collect_errors!
      @expression_errors = resolver&.expression_errors || []
    end
  end
end
