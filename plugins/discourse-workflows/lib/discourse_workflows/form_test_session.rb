# frozen_string_literal: true

module DiscourseWorkflows
  class FormTestSession
    TTL = 120.seconds
    CACHE_PREFIX = "discourse_workflows:form_test_session"

    def self.create!(workflow:, user:, trigger_node_id:)
      token = SecureRandom.uuid
      payload = {
        "workflow_id" => workflow.id,
        "user_id" => user.id,
        "trigger_node_id" => trigger_node_id.to_s,
        "workflow_data" => WorkflowSnapshot.from_workflow(workflow).to_h,
      }

      Discourse.cache.write(cache_key(token), payload, expires_in: TTL)
      token
    end

    def self.find(token)
      payload = Discourse.cache.read(cache_key(token))
      return if payload.blank?

      new(token:, payload: payload.deep_stringify_keys)
    end

    attr_reader :token, :workflow_id, :user_id, :trigger_node_id, :workflow_snapshot

    def initialize(token:, payload:)
      @token = token
      @workflow_id = payload["workflow_id"].to_i
      @user_id = payload["user_id"].to_i
      @trigger_node_id = payload["trigger_node_id"].to_s
      @workflow_snapshot = WorkflowSnapshot.new(payload["workflow_data"])
    end

    def trigger_node
      workflow_snapshot.find_node(trigger_node_id)
    end

    def owned_by?(user)
      user.present? && user.id == user_id
    end

    def self.cache_key(token)
      "#{CACHE_PREFIX}:#{token}"
    end
    private_class_method :cache_key
  end
end
