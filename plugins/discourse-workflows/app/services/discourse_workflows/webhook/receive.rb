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

      only_if(:sync_resume?) { step :execute_sync_resume }
    end

    only_if(:triggering_new_workflow) do
      model :webhook_nodes, :find_webhook_nodes
      step :authenticate_nodes
      step :enqueue_async_workflows
      step :execute_sync_workflows
    end

    private

    def fetch_waiting_execution(params:)
      DiscourseWorkflows::Execution
        .where(status: :waiting)
        .where("waiting_config->>'resume_token' = ?", params.path)
        .where("waiting_config->>'wait_type' = ?", "webhook")
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
      response_mode = waiting_execution.waiting_config["response_mode"] || "immediately"
      response_mode == "immediately"
    end

    def sync_resume?(waiting_execution:)
      response_mode = waiting_execution.waiting_config["response_mode"] || "immediately"
      response_mode != "immediately"
    end

    def enqueue_async_resume(waiting_execution:, params:)
      token = waiting_execution.waiting_config["resume_token"]
      Jobs.enqueue(
        Jobs::DiscourseWorkflows::ResumeWebhookWaiting,
        execution_id: waiting_execution.id,
        response_items: params.response_items_for(token),
      )
    end

    def execute_sync_resume(waiting_execution:, params:)
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
      candidates =
        DiscourseWorkflows::Node.enabled_of_type("trigger:webhook").where(
          "discourse_workflows_nodes.configuration->>'http_method' = ?",
          params.http_method,
        )

      resolver = DiscourseWorkflows::ExpressionResolver.new({})
      candidates.select { |node| resolver.resolve(node.configuration["path"]) == params.path }
    end

    def authenticate_nodes(webhook_nodes:, params:)
      authenticated = webhook_nodes.select { |node| node_passes_auth?(node, params) }

      context[:all_nodes_rejected_auth] = true if authenticated.empty? && webhook_nodes.any?

      context[:webhook_nodes] = authenticated
    end

    def node_passes_auth?(node, params)
      auth_mode = node.configuration["authentication"] || "none"
      return true if auth_mode == "none"

      return false unless auth_mode == "basic_auth"

      credential_id = node.configuration["credential_id"]
      credential = DiscourseWorkflows::Credential.find_by(id: credential_id)
      unless credential
        Rails.logger.warn("Workflow credential not found (id=#{credential_id}) for node #{node.id}")
        return false
      end

      begin
        cred_data = credential.decrypted_data
      rescue ActiveSupport::MessageEncryptor::InvalidMessage => e
        Rails.logger.warn(
          "Workflow credential decryption failed (id=#{credential_id}) for node #{node.id}: #{e.message}",
        )
        return false
      end

      resolver = DiscourseWorkflows::ExpressionResolver.new({})
      expected_user = resolver.resolve(cred_data["user"])
      expected_password = resolver.resolve(cred_data["password"])

      headers = params.headers
      auth_header =
        headers[:authorization] || headers["authorization"] || headers[:Authorization] ||
          headers["Authorization"]
      return false unless auth_header&.start_with?("Basic ")

      decoded = Base64.decode64(auth_header.split(" ", 2).last)
      request_user, request_password = decoded.split(":", 2)

      ActiveSupport::SecurityUtils.secure_compare(request_user.to_s, expected_user.to_s) &&
        ActiveSupport::SecurityUtils.secure_compare(request_password.to_s, expected_password.to_s)
    end

    def enqueue_async_workflows(webhook_nodes:, params:)
      webhook_nodes.each do |node|
        next unless (node.configuration["response_mode"] || "immediately") == "immediately"

        Jobs.enqueue(
          Jobs::DiscourseWorkflows::ExecuteWorkflow,
          trigger_node_id: node.id,
          trigger_data: params.trigger_data,
        )
      end
    end

    def execute_sync_workflows(webhook_nodes:, params:)
      webhook_nodes.each do |node|
        response_mode = node.configuration["response_mode"] || "immediately"
        next if response_mode == "immediately"

        executor = DiscourseWorkflows::Executor.new(node, params.trigger_data)
        execution = executor.run

        context[:sync_execution] ||= execution
        context[:sync_response_mode] ||= response_mode
        context[:sync_response_code] ||= node.configuration["response_code"]
      end
    end
  end
end
