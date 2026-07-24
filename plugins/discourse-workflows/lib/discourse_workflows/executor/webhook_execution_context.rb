# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class WebhookExecutionContext
      attr_reader :http_method, :path, :params, :webhook, :user, :node_id

      delegate :input_items,
               :get_node_parameter,
               :get_node,
               :get_workflow,
               :get_child_nodes,
               :get_parent_nodes,
               :helpers,
               to: :@node_execution_context

      def initialize(
        execution:,
        node:,
        node_type_class:,
        webhook:,
        http_method:,
        path:,
        params: {},
        service_params: {}
      )
        @execution = execution
        @node = node
        @node_type_class = node_type_class
        @webhook = webhook
        @http_method = http_method.to_s
        @path = path.to_s
        @params = params || {}
        @service_params = service_params || {}
        @guardian = @service_params[:guardian] || @service_params["guardian"]
        @user = @guardian&.user
        @node_id = node_value("id").to_s
        @node_identifier = node_value("type").to_s
        @snapshot = execution_snapshot

        build_context!
      end

      def trigger_data
        @execution.trigger_data || {}
      end

      def get_request_object
        {
          "method" => http_method,
          "path" => path,
          "body" => get_body_data,
          "query" => get_query_data,
          "headers" => get_header_data,
        }
      end

      def get_body_data
        params
      end

      def get_query_data
        params[:query] || params["query"] || {}
      end

      def get_header_data
        params[:headers] || params["headers"] || {}
      end

      def resolve(value, item_index = 0)
        @node_execution_context.evaluate_expression(value, item_index)
      end

      def dispose
        @resolver&.dispose
        @sandbox&.dispose
      end

      private

      def build_context!
        @execution_context =
          ExecutionContext.new(
            workflow: @execution.workflow,
            trigger_data: trigger_data,
            user: user,
            execution: @execution,
            workflow_nodes: @snapshot.to_h["nodes"],
            workflow_name: @snapshot.workflow_name,
          )
        @execution_context.restore!(
          context: @execution.execution_data&.context_data || {},
          node_contexts: @execution.execution_data&.node_contexts || {},
          resume_token: @execution.resume_token,
        )

        current_item = waiting_input_items.first || { "json" => {} }
        node_context = @execution_context.node_context_for(snapshot_node(@node_id))
        resolver_context =
          @execution_context.resolver_context(
            "__input_item" => current_item,
            "__input_items" => waiting_input_items,
            "__input_params" => parameters,
            "__input_context" => DiscourseWorkflows::InputContext.from_node_context(node_context),
            "__current_node_id" => @node_id,
            "__node_parameters_by_name" => node_parameters_by_name,
            "$itemIndex" => 0,
          )
        resolver_context.merge!("$json" => current_item.fetch("json") { {} })

        @sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context, user: user)
        @resolver =
          DiscourseWorkflows::ExpressionResolver.new(
            resolver_context,
            user: user,
            sandbox: @sandbox,
          )
        @node_execution_context =
          NodeExecutionContext.new(
            input_items: waiting_input_items,
            parameters: parameters,
            credentials: credentials,
            node_settings: DiscourseWorkflows::NodeData.direct_settings(@node),
            webhook_id: webhook_id,
            property_schema: @node_type_class.property_schema,
            credential_schema: @node_type_class.credentials,
            node_context: node_context,
            user: user,
            resolver: @resolver,
            workflow: @execution.workflow,
            execution_id: @execution.id,
            resume_token: @execution.resume_token,
            node_id: @node_id,
            node_identifier: @node_identifier,
            execution_mode: @execution.execution_mode.to_sym,
            flow_context: @execution_context.context,
            resolver_context: resolver_context,
            workflow_snapshot: @snapshot,
          )
      end

      def execution_snapshot
        if @execution.execution_data&.workflow_data.present?
          WorkflowSnapshot.new(@execution.execution_data.workflow_data)
        else
          WorkflowSnapshot.from_workflow(@execution.workflow, published: true)
        end
      end

      def waiting_input_items
        @waiting_input_items ||= @execution.waiting_step_input_items
      end

      def node_parameters_by_name
        @node_parameters_by_name ||=
          @snapshot
            .nodes
            .each_with_object({}) do |node, by_name|
              name = node.name.to_s
              next if name.blank?

              by_name[name] = by_name.key?(name) ? nil : node.parameters
            end
            .compact
      end

      def snapshot_node(node_id)
        @snapshot.find_node(node_id)
      end

      def parameters
        @parameters ||= DiscourseWorkflows::NodeData.parameters(@node)
      end

      def credentials
        @credentials ||= DiscourseWorkflows::NodeData.credentials(@node)
      end

      def webhook_id
        DiscourseWorkflows::NodeData.webhook_id(@node)
      end

      def node_value(key)
        DiscourseWorkflows::NodeData.read(@node, key)
      end
    end
  end
end
