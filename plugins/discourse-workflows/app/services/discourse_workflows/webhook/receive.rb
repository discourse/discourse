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
    end

    model :waiting_execution, optional: true

    only_if(:resuming_execution) do
      step :validate_waiting_http_method
      step :resume_waiting_execution
    end

    only_if(:triggering_new_workflow) do
      model :webhook_nodes, :find_webhook_nodes
      step :trigger_webhook_nodes
    end

    private

    def fetch_waiting_execution(params:)
      DiscourseWorkflows::Execution
        .where(status: :waiting)
        .where("waiting_config->>'resume_token' = ?", params.path)
        .where("waiting_config->>'wait_type' = ?", "webhook")
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

    def resume_waiting_execution(waiting_execution:, params:)
      config = waiting_execution.waiting_config
      token = config["resume_token"]
      response_items = [
        {
          "json" => {
            "body" => params.body,
            "headers" => params.headers,
            "query" => params.query_params,
            "method" => params.http_method,
            "webhook_url" => "#{Discourse.base_url}/workflows/webhooks/#{token}",
          },
        },
      ]

      response_mode = config["response_mode"] || "immediately"

      if response_mode == "immediately"
        Jobs.enqueue(
          Jobs::DiscourseWorkflows::ResumeWebhookWaiting,
          execution_id: waiting_execution.id,
          response_items: response_items,
        )
      else
        context[:sync_execution] = DiscourseWorkflows::Executor.resume(
          waiting_execution,
          response_items,
        )
        context[:sync_response_mode] = response_mode
        context[:sync_response_code] = config["response_code"]
      end
    end

    def find_webhook_nodes(params:)
      candidates =
        DiscourseWorkflows::Node.enabled_of_type("trigger:webhook").where(
          "discourse_workflows_nodes.configuration->>'http_method' = ?",
          params.http_method,
        )

      resolver = DiscourseWorkflows::ExpressionResolver.new({})
      candidates.select { |node| resolver.resolve(node.configuration["path"]) == params.path }
    end

    def trigger_webhook_nodes(webhook_nodes:, params:)
      trigger_data = {
        body: params.body,
        headers: params.headers,
        query: params.query_params,
        method: params.http_method,
        webhook_url: "#{Discourse.base_url}/workflows/webhooks/#{params.path}",
      }

      webhook_nodes.each do |node|
        response_mode = node.configuration["response_mode"] || "immediately"

        if response_mode == "immediately"
          Jobs.enqueue(
            Jobs::DiscourseWorkflows::ExecuteWorkflow,
            trigger_node_id: node.id,
            trigger_data: trigger_data,
          )
        else
          executor = DiscourseWorkflows::Executor.new(node, trigger_data)
          execution = executor.run

          context[:sync_execution] ||= execution
          context[:sync_response_mode] ||= response_mode
          context[:sync_response_code] ||= node.configuration["response_code"]
        end
      end
    end
  end
end
