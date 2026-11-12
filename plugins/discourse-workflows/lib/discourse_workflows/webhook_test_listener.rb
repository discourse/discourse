# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookTestListener
    class ActiveRouteExists < StandardError
    end

    TTL = 120.seconds

    def self.create!(workflow:, user:, trigger_node:)
      parameters = NodeData.parameters(trigger_node)
      http_method = Webhook.normalize_method(parameters["http_method"].to_s)
      webhook_path = Webhook.normalize_path(parameters["path"].to_s)
      listener_id = SecureRandom.uuid
      snapshot = WorkflowSnapshot.from_workflow(workflow).to_h
      node_name = trigger_node["name"].to_s

      record =
        Webhook.transaction do
          Webhook
            .test_listeners
            .where(http_method: http_method, webhook_path: webhook_path)
            .find_each do |existing|
              if existing_can_be_replaced?(existing, workflow:, user:, node_name:)
                existing.destroy!
              else
                raise ActiveRouteExists
              end
            end

          Webhook.create!(
            workflow_id: workflow.id,
            node_name: node_name,
            webhook_path: webhook_path,
            http_method: http_method,
            webhook_id: listener_id,
            test_webhook: true,
            user_id: user.id,
            workflow_snapshot: snapshot,
            expires_at: Time.current + TTL,
          )
        end

      ActiveWebhooks.invalidate!
      new(record)
    rescue ActiveRecord::RecordNotUnique
      raise ActiveRouteExists
    end

    def self.find(listener_id)
      record = Webhook.test_listeners.live.find_by(webhook_id: listener_id.to_s)
      record ? new(record) : nil
    end

    def self.find_by_route(method:, path:)
      record =
        Webhook.test_listeners.live.find_by(
          http_method: Webhook.normalize_method(method),
          webhook_path: Webhook.normalize_path(path),
        )
      record ? new(record) : nil
    end

    def self.find_for_request(listener_id:, method:, path:)
      record =
        Webhook.test_listeners.live.find_by(
          webhook_id: listener_id.to_s,
          http_method: Webhook.normalize_method(method),
          webhook_path: Webhook.normalize_path(path),
        )
      record ? new(record) : nil
    end

    def self.claim(listener)
      deleted = Webhook.test_listeners.where(id: listener.id).delete_all
      return nil if deleted.zero?

      ActiveWebhooks.invalidate!
      listener
    end

    def self.cancel!(listener)
      Webhook.test_listeners.where(id: listener.id).delete_all
      ActiveWebhooks.invalidate!
    end

    def self.purge_expired!
      deleted = Webhook.test_listeners.expired.delete_all
      ActiveWebhooks.invalidate! if deleted.positive?
      deleted
    end

    attr_reader :id,
                :listener_id,
                :workflow_id,
                :user_id,
                :trigger_node_name,
                :http_method,
                :path,
                :workflow_snapshot,
                :expires_at

    def initialize(record)
      @id = record.id
      @listener_id = record.webhook_id.to_s
      @workflow_id = record.workflow_id
      @user_id = record.user_id
      @trigger_node_name = record.node_name.to_s
      @http_method = record.http_method
      @path = record.webhook_path
      @workflow_snapshot = WorkflowSnapshot.new(record.workflow_snapshot || {})
      @expires_at = record.expires_at || (Time.current + TTL)
    end

    def trigger_node
      workflow_snapshot.find_node_by_name(trigger_node_name)
    end

    def trigger_node_id
      trigger_node&.id
    end

    def owned_by?(user)
      user.present? && user.id == user_id
    end

    def test_url
      "/workflows/webhook-test/#{listener_id}/#{path}"
    end

    def self.existing_can_be_replaced?(existing, workflow:, user:, node_name:)
      return true if existing.expires_at.present? && existing.expires_at <= Time.current

      existing.workflow_id == workflow.id && existing.user_id == user.id &&
        existing.node_name.to_s == node_name
    end
    private_class_method :existing_can_be_replaced?
  end
end
