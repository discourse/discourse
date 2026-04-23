# frozen_string_literal: true

module DiscourseWorkflows
  class Webhook::Receive
    include Service::Base

    params do
      attribute :execution_id, :integer
      attribute :token, :string
      attribute :webhook_suffix, :string
      attribute :path, :string
      attribute :http_method, :string
      attribute :body, default: -> { {} }
      attribute :headers, default: -> { {} }
      attribute :query_params, default: -> { {} }
      attribute :raw_authorization, :string

      validates :http_method, presence: true

      def webhook_url
        if execution_id.present?
          base = "#{Discourse.base_url}/workflows/webhooks/#{execution_id}"
          base = "#{base}/#{webhook_suffix}" if webhook_suffix.present?
          "#{base}?token=#{token}"
        else
          "#{Discourse.base_url}/workflows/webhooks/#{path}"
        end
      end

      def trigger_data
        {
          body: body,
          headers: headers,
          query: query_params,
          method: http_method,
          webhook_url: webhook_url,
        }
      end

      def response_items
        [
          {
            "json" => {
              "body" => body,
              "headers" => headers,
              "query" => query_params,
              "method" => http_method,
              "webhook_url" => webhook_url,
            },
          },
        ]
      end
    end

    model :waiting_execution, optional: true
    step :validate_resume_request

    only_if(:resuming_execution) do
      step :validate_waiting_http_method

      only_if(:async_resume?) { step :enqueue_async_resume }

      only_if(:sync_resume?) { step :resume_execution_synchronously }
    end

    only_if(:triggering_new_workflow) do
      model :webhook_nodes, :find_webhook_nodes
      model :authenticated_nodes, :filter_authenticated_nodes
      step :enqueue_async_workflows
      step :execute_sync_workflows
    end

    private

    def validate_resume_request(waiting_execution:, params:)
      fail!("invalid resume request") if params.execution_id.present? && waiting_execution.nil?
    end

    def fetch_waiting_execution(params:)
      return nil if params.execution_id.blank? || params.token.blank?

      execution =
        DiscourseWorkflows::Execution
          .where(status: :waiting)
          .where(resume_token: params.token)
          .find_by(id: params.execution_id)
      return nil unless execution
      unless ActiveSupport::SecurityUtils.secure_compare(execution.resume_token, params.token)
        return nil
      end

      waiting_node = execution.workflow.find_node(execution.waiting_node_id)
      return nil unless waiting_node

      suffix = params.webhook_suffix.to_s
      stored_suffix = waiting_node.dig("configuration", "webhook_suffix").to_s
      return nil unless suffix == stored_suffix

      execution.lock!("FOR UPDATE SKIP LOCKED")
      execution
    end

    def resuming_execution(waiting_execution:)
      waiting_execution.present?
    end

    def triggering_new_workflow(waiting_execution:, params:)
      waiting_execution.nil? && params.execution_id.blank?
    end

    def validate_waiting_http_method(waiting_execution:, params:)
      node = waiting_execution.workflow.find_node(waiting_execution.waiting_node_id)
      unless node&.dig("configuration", "http_method") == params.http_method
        fail!("HTTP method mismatch")
      end
    end

    def async_resume?(waiting_execution:)
      node = waiting_execution.workflow.find_node(waiting_execution.waiting_node_id)
      response_mode =
        node&.dig("configuration", "response_mode") || Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY
      response_mode == Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY
    end

    def sync_resume?(waiting_execution:)
      !async_resume?(waiting_execution:)
    end

    def enqueue_async_resume(waiting_execution:, params:)
      Jobs.enqueue(
        Jobs::DiscourseWorkflows::ResumeWebhookWaiting,
        execution_id: waiting_execution.id,
        response_items: params.response_items,
      )
    end

    def resume_execution_synchronously(waiting_execution:, params:)
      node = waiting_execution.workflow.find_node(waiting_execution.waiting_node_id)
      config = node&.dig("configuration") || {}

      context[:sync_execution] = DiscourseWorkflows::Executor.resume(
        waiting_execution,
        params.response_items,
      )
      context[:sync_response_mode] = config["response_mode"]
      context[:sync_response_code] = config["response_code"]
    end

    def find_webhook_nodes(params:)
      workflow_ids =
        DiscourseWorkflows::WorkflowDependency.where(
          dependency_type: "webhook_path",
          dependency_key: params.path,
        ).pluck(:workflow_id)

      DiscourseWorkflows::Workflow
        .enabled
        .where(id: workflow_ids)
        .flat_map do |workflow|
          workflow
            .nodes_of_type("trigger:webhook")
            .select do |node|
              config = node["configuration"] || {}
              config["path"] == params.path && config["http_method"] == params.http_method
            end
            .map { |node| [workflow, node] }
        end
    end

    def filter_authenticated_nodes(webhook_nodes:, params:)
      webhook_nodes.select do |_workflow, node|
        Webhook::Action::AuthenticateNode.call(node:, params:)
      end
    end

    def enqueue_async_workflows(authenticated_nodes:, params:)
      authenticated_nodes.each do |workflow, node|
        response_mode =
          node.dig("configuration", "response_mode") || Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY
        next unless response_mode == Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY

        Jobs.enqueue(
          Jobs::DiscourseWorkflows::ExecuteWorkflow,
          workflow_id: workflow.id,
          trigger_node_id: node["id"],
          trigger_data: params.trigger_data,
        )
      end
    end

    def execute_sync_workflows(authenticated_nodes:, params:)
      authenticated_nodes.each do |workflow, node|
        response_mode =
          node.dig("configuration", "response_mode") || Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY
        next if response_mode == Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY

        executor = DiscourseWorkflows::Executor.new(workflow, node["id"], params.trigger_data)
        execution = executor.run

        context[:sync_execution] ||= execution
        context[:sync_response_mode] ||= response_mode
        context[:sync_response_code] ||= node.dig("configuration", "response_code")
      end
    end
  end
end
