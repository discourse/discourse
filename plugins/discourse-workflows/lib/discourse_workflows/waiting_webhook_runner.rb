# frozen_string_literal: true

module DiscourseWorkflows
  class WaitingWebhookRunner
    Response = Struct.new(:status, :body, keyword_init: true)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def self.waiting_for?(execution, node_type:)
      return false unless execution&.waiting?

      node = execution.find_waiting_node
      return false if node.blank?

      node_class =
        Registry.find_node_type(NodeData.read(node, "type"), version: NodeData.type_version(node))
      return false unless node_class

      node_class.waiting_webhook_for(http_method: "GET", path: "", node_type: node_type).present?
    end

    def initialize(
      execution_id:,
      signature:,
      http_method:,
      path:,
      node_type:,
      params: {},
      service_params: {}
    )
      @execution_id = execution_id
      @signature = signature
      @http_method = http_method
      @path = path.to_s
      @node_type = node_type.to_s
      @params = params || {}
      @service_params = service_params || {}
    end

    def call
      execution = WaitingExecution.find(execution_id: @execution_id, signature: @signature)
      return not_found unless execution

      node = execution.find_waiting_node
      return not_found if node.blank?

      node_class =
        Registry.find_node_type(NodeData.read(node, "type"), version: NodeData.type_version(node))
      return not_found unless node_class

      webhook =
        node_class.waiting_webhook_for(
          http_method: @http_method,
          path: @path,
          node_type: @node_type,
        )
      return not_found unless webhook

      webhook_context =
        Executor::WebhookExecutionContext.new(
          execution: execution,
          node: node,
          node_type_class: node_class,
          webhook: webhook,
          http_method: @http_method,
          path: @path,
          params: @params,
          service_params: @service_params,
        )
      node_parameters = NodeData.parameters(node)
      node =
        node_class.new(
          parameters: node_parameters,
          credentials: NodeData.credentials(node),
          webhook_id: NodeData.webhook_id(node),
        )
      response = node.webhook(webhook_context)
      return response_from(response, execution) unless response.resume?

      resume_execution(execution, response.workflow_data, node_class, node_parameters)
    ensure
      webhook_context&.dispose
    end

    private

    def resume_execution(execution, workflow_data, node_class, node_parameters)
      DiscourseWorkflows::ItemContract.validate_output_arrays!(
        workflow_data,
        source: "webhook:#{execution.waiting_node_id}",
        ports: node_class.ports(node_parameters),
      )
      response_items = workflow_data.fetch(0) { [] }

      claimed_execution = WaitingExecution.claim(execution, signature: @signature)
      unless claimed_execution
        return(
          Response.new(
            status: :conflict,
            body: {
              error: I18n.t("discourse_workflows.errors.already_resumed"),
            },
          )
        )
      end

      resumed_execution =
        WaitingExecution.resume_claimed(
          claimed_execution,
          response_items,
          user: guardian_user,
        ).reload

      Response.new(
        status: response_status_for(resumed_execution),
        body: response_body_for(resumed_execution),
      )
    end

    def response_body_for(execution)
      return DiscourseWorkflows::FormResponse.resumed_submission(execution) if @node_type == "form"

      { status: execution.status }
    end

    def response_status_for(execution)
      if @node_type == "form"
        return DiscourseWorkflows::FormResponse.resumed_submission_status(execution)
      end

      :ok
    end

    def response_from(response, execution)
      body = response.body
      if @node_type == "form" && @http_method == "GET" && @path.blank? && response.status == :ok
        body = body.merge(DiscourseWorkflows::WaitingExecution.form_urls(execution))
      end

      Response.new(status: response.status, body: body)
    end

    def guardian_user
      guardian = @service_params[:guardian] || @service_params["guardian"]
      guardian&.user
    end

    def not_found
      Response.new(status: :not_found, body: { error: "not_found" })
    end
  end
end
