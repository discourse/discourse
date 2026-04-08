# frozen_string_literal: true

module DiscourseWorkflows
  class Webhook::Receive
    include Service::Base

    params do
      attribute :path, :string
      attribute :http_method, :string
      attribute :body, default: -> { {} }
      attribute :headers, default: -> { {} }
      attribute :query_params, default: -> { {} }
      attribute :raw_authorization, :string

      validates :path, presence: true
      validates :http_method, presence: true

      def webhook_url
        "#{Discourse.base_url}/workflows/webhooks/#{path}"
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

      def response_items_for(token)
        [
          {
            "json" => {
              "body" => body,
              "headers" => headers,
              "query" => query_params,
              "method" => http_method,
              "webhook_url" => "#{Discourse.base_url}/workflows/webhooks/#{token}",
            },
          },
        ]
      end
    end

    model :waiting_execution, optional: true

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

    def fetch_waiting_execution(params:)
      token, signature = params.path.to_s.split(":", 2)
      return nil if token.blank? || signature.blank?
      return nil unless DiscourseWorkflows::HmacSigner.verify(token, signature)

      DiscourseWorkflows::Executor::WaitHandlers::Webhook
        .find_waiting_execution_by_resume_token(token)
        .lock("FOR UPDATE SKIP LOCKED")
        .first
    end

    def resuming_execution(waiting_execution:)
      waiting_execution.present?
    end

    def triggering_new_workflow(waiting_execution:)
      waiting_execution.nil?
    end

    def validate_waiting_http_method(waiting_execution:, params:)
      unless waiting_execution.waiting_config["http_method"] == params.http_method
        fail!("HTTP method mismatch")
      end
    end

    def async_resume?(waiting_execution:)
      response_mode =
        waiting_execution.waiting_config["response_mode"] ||
          Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY
      response_mode == Schemas::Webhook::RESPONSE_MODE_IMMEDIATELY
    end

    def sync_resume?(waiting_execution:)
      !async_resume?(waiting_execution:)
    end

    def enqueue_async_resume(waiting_execution:, params:)
      token = waiting_execution.waiting_config["resume_token"]
      Jobs.enqueue(
        Jobs::DiscourseWorkflows::ResumeWebhookWaiting,
        execution_id: waiting_execution.id,
        response_items: params.response_items_for(token),
      )
    end

    def resume_execution_synchronously(waiting_execution:, params:)
      config = waiting_execution.waiting_config
      token = config["resume_token"]

      context[:sync_execution] = DiscourseWorkflows::Executor.resume(
        waiting_execution,
        params.response_items_for(token),
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
