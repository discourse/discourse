# frozen_string_literal: true

module DiscourseWorkflows
  class Webhook::Action::ActivateWebhooks < Service::ActionBase
    class CollisionError < StandardError
      attr_reader :method, :path

      def initialize(method:, path:)
        @method = method
        @path = path
        super("Webhook route already registered for #{method} #{path}")
      end
    end

    option :workflow
    option :workflow_version

    def call
      rows = build_rows
      collision = detect_collision(rows)
      raise collision if collision

      begin
        Webhook.transaction(requires_new: true) do
          Webhook.production.where(workflow_id: workflow.id).delete_all
          Webhook.insert_all!(rows) if rows.any?
        end
      rescue ActiveRecord::RecordNotUnique
        raise(detect_collision(rows) || generic_collision(rows))
      end

      ActiveWebhooks.invalidate!
      rows
    end

    private

    def build_rows
      workflow_version.nodes.filter_map do |node|
        next unless node["type"] == "trigger:webhook"

        parameters = NodeData.parameters(node)
        path = parameters["path"].to_s
        method = parameters["http_method"].to_s
        next if path.blank? || method.blank?

        dynamic = Webhook.dynamic_path?(path)
        {
          workflow_id: workflow.id,
          workflow_version_id: workflow_version.version_id,
          node_name: node["name"].to_s,
          webhook_path: Webhook.normalize_path(path),
          http_method: Webhook.normalize_method(method),
          webhook_id: dynamic ? node["webhookId"] : nil,
          path_length: dynamic ? Webhook.path_length_for(path) : nil,
          test_webhook: false,
          created_at: Time.current,
        }
      end
    end

    def detect_collision(rows)
      rows.each do |row|
        owner =
          Webhook.production.find_by(
            http_method: row[:http_method],
            webhook_path: row[:webhook_path],
          )
        next if owner.nil? || owner.workflow_id == workflow.id

        return CollisionError.new(method: row[:http_method], path: row[:webhook_path])
      end
      nil
    end

    def generic_collision(rows)
      row = rows.first || { http_method: "", webhook_path: "" }
      CollisionError.new(method: row[:http_method], path: row[:webhook_path])
    end
  end
end
