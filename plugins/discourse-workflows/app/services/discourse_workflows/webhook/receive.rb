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

    model :webhook_nodes
    step :enqueue_executions

    private

    def fetch_webhook_nodes(params:)
      candidates =
        DiscourseWorkflows::Node.enabled_of_type("trigger:webhook").where(
          "discourse_workflows_nodes.configuration->>'http_method' = ?",
          params.http_method,
        )

      resolver = DiscourseWorkflows::ExpressionResolver.new({})
      candidates.select { |node| resolver.resolve(node.configuration["path"]) == params.path }
    end

    def enqueue_executions(webhook_nodes:, params:)
      trigger_data = {
        body: params.body,
        headers: params.headers,
        query: params.query_params,
        method: params.http_method,
        webhook_url: "#{Discourse.base_url}/workflows/webhooks/#{params.path}",
      }

      webhook_nodes.each do |node|
        Jobs.enqueue(
          Jobs::DiscourseWorkflows::ExecuteWorkflow,
          trigger_node_id: node.id,
          trigger_data: trigger_data,
        )
      end
    end
  end
end
