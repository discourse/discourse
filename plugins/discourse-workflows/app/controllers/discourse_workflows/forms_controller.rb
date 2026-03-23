# frozen_string_literal: true

module DiscourseWorkflows
  class FormsController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required
    skip_before_action :check_xhr

    def show
      if request.format.json?
        form_node = find_form_node_or_waiting_node
        raise Discourse::NotFound if form_node.nil?
        render json: serialize_form(form_node)
      else
        render html: "", layout: "application"
      end
    end

    def submit
      if params[:execution_id].present?
        resume_form_submission
      else
        initial_form_submission
      end
    end

    private

    def find_form_node_or_waiting_node
      if params[:execution_id].present?
        @waiting_execution = find_waiting_form_execution
        return nil if @waiting_execution.nil?

        @waiting_execution.workflow.nodes.find_by(id: @waiting_execution.waiting_node_id)
      else
        find_trigger_node
      end
    end

    def find_waiting_form_execution
      execution = DiscourseWorkflows::Execution.find_by(id: params[:execution_id], status: :waiting)
      return nil if execution.nil?
      return nil if execution.waiting_config&.dig("wait_type") != "form"
      execution
    end

    def find_trigger_node
      DiscourseWorkflows::Node.enabled_of_type("trigger:form").find_by(
        "configuration->>'uuid' = ?",
        params[:uuid],
      )
    end

    def serialize_form(node)
      if @waiting_execution
        wc = @waiting_execution.waiting_config
        {
          uuid: params[:uuid],
          form_title: wc["form_title"],
          form_description: wc["form_description"],
          form_fields: wc["form_fields"] || [],
          response_mode: "on_received",
          has_downstream_form: has_downstream_form?(node),
        }
      else
        resolver = ExpressionResolver.new({})
        config = resolver.resolve_hash(node.configuration.deep_stringify_keys)
        {
          uuid: params[:uuid],
          form_title: config["form_title"],
          form_description: config["form_description"],
          form_fields: config["form_fields"] || [],
          response_mode: config["response_mode"] || "on_received",
          has_downstream_form: has_downstream_form?(node),
        }
      end
    end

    def has_downstream_form?(node)
      node
        .outgoing_connections
        .joins(:target_node)
        .where(discourse_workflows_nodes: { type: "action:form" })
        .exists?
    end

    def initial_form_submission
      trigger_node = find_trigger_node
      raise Discourse::NotFound if trigger_node.nil?

      form_data = build_form_data(trigger_node)
      has_downstream = has_downstream_form?(trigger_node)
      trigger_data = { form_data: form_data, submitted_at: Time.current.utc.iso8601 }

      execution = DiscourseWorkflows::Executor.new(trigger_node, trigger_data).run

      render json: {
               execution_id: execution&.id,
               has_downstream_form: has_downstream,
               response_mode: trigger_node.configuration["response_mode"] || "on_received",
             }
    end

    def resume_form_submission
      execution = find_waiting_form_execution
      raise Discourse::NotFound if execution.nil?

      waiting_node = execution.workflow.nodes.find_by(id: execution.waiting_node_id)
      raise Discourse::NotFound if waiting_node.nil?

      form_data = accumulated_form_data(execution).merge(build_form_data(waiting_node))

      response_items = [
        { "json" => { "form_data" => form_data, "submitted_at" => Time.current.utc.iso8601 } },
      ]
      DiscourseWorkflows::Executor.resume(execution, response_items)

      render json: { execution_id: execution.id }
    end

    def build_form_data(node)
      (node.configuration["form_fields"] || []).each_with_object({}) do |field, data|
        key = field["field_label"].to_s.parameterize(separator: "_")
        data[key] = params.dig(:form_data, key)
      end
    end

    def accumulated_form_data(execution)
      context = execution.context || {}
      form_data = {}
      context.each_value do |items|
        next unless items.is_a?(Array)
        items.each do |item|
          next unless item.is_a?(Hash) && item.dig("json", "form_data").is_a?(Hash)
          form_data.merge!(item["json"]["form_data"])
        end
      end
      form_data
    end
  end
end
