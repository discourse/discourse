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

    step :route_request

    private

    def route_request(params:)
      waiting = find_waiting_execution(params.path)

      if waiting
        resume_waiting_execution(waiting, params)
      else
        trigger_webhooks(params)
      end
    end

    def find_waiting_execution(token)
      DiscourseWorkflows::Execution
        .where(status: :waiting)
        .where("waiting_config->>'resume_token' = ?", token)
        .where("waiting_config->>'wait_type' = ?", "webhook")
        .first
    end

    def resume_waiting_execution(execution, params)
      config = execution.waiting_config

      unless config["http_method"] == params.http_method
        context[:not_found] = true
        return
      end

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
          execution_id: execution.id,
          response_items: response_items,
        )
      else
        result_execution = DiscourseWorkflows::Executor.resume(execution, response_items)
        context[:sync_execution] = result_execution
        context[:sync_response_mode] = response_mode
        context[:sync_response_code] = config["response_code"]
      end
    end

    def trigger_webhooks(params)
      webhook_nodes = find_webhook_nodes(params)

      if webhook_nodes.blank?
        context[:not_found] = true
        return
      end

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

    def find_webhook_nodes(params)
      candidates =
        DiscourseWorkflows::Node.enabled_of_type("trigger:webhook").where(
          "discourse_workflows_nodes.configuration->>'http_method' = ?",
          params.http_method,
        )

      resolver = DiscourseWorkflows::ExpressionResolver.new({})
      candidates.select { |node| resolver.resolve(node.configuration["path"]) == params.path }
    end
  end
end
