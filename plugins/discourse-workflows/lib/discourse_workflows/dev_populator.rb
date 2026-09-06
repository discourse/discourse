# frozen_string_literal: true

module DiscourseWorkflows
  class DevPopulator
    MANUAL_LOG_WORKFLOW_NAME = "Example: Log manual trigger"
    TOPIC_BUTTON_WORKFLOW_NAME = "Example: Topic admin reply button"

    def self.populate!
      new.populate!
    end

    def populate!
      if !Rails.env.development?
        raise "Workflow examples are only supported in development environment"
      end

      SiteSetting.set(:enable_discourse_workflows, true) if !SiteSetting.enable_discourse_workflows

      ensure_manual_log_workflow!
      ensure_topic_admin_button_workflow!
    end

    private

    def ensure_manual_log_workflow!
      ensure_workflow!(
        name: MANUAL_LOG_WORKFLOW_NAME,
        nodes: [
          node(
            id: "manual-trigger",
            type: "trigger:manual",
            name: "Manual trigger",
            position: {
              "x" => 80,
              "y" => 120,
            },
          ),
          node(
            id: "write-log",
            type: "action:log",
            name: "Write log",
            position: {
              "x" => 360,
              "y" => 120,
            },
            parameters: {
              "mode" => "runOnceForAllItems",
              "entries" => {
                "values" => [
                  { "key" => "message", "value" => "Hello from an example Discourse workflow" },
                ],
              },
            },
          ),
        ],
        connections: {
          "Manual trigger" => {
            "main" => [[{ "node" => "Write log", "type" => "main", "index" => 0 }]],
          },
        },
      )
    end

    def ensure_topic_admin_button_workflow!
      ensure_workflow!(
        name: TOPIC_BUTTON_WORKFLOW_NAME,
        nodes: [
          node(
            id: "topic-admin-button",
            type: "trigger:topic_admin_button",
            name: "Topic admin button",
            position: {
              "x" => 80,
              "y" => 320,
            },
            parameters: {
              "label" => "Add workflow note",
              "icon" => "bolt",
            },
          ),
          node(
            id: "create-reply",
            type: "action:post",
            name: "Create reply",
            position: {
              "x" => 360,
              "y" => 320,
            },
            parameters: {
              "operation" => "create",
              "topic_id" => "={{ $json.topic.id }}",
              "raw" => "This automated reply was created by an example Discourse workflow.",
              "author_username" => "system",
            },
          ),
        ],
        connections: {
          "Topic admin button" => {
            "main" => [[{ "node" => "Create reply", "type" => "main", "index" => 0 }]],
          },
        },
      )
    end

    def ensure_workflow!(name:, nodes:, connections:)
      workflow = Workflow.find_by(name: name)
      return workflow if workflow

      workflow =
        Workflow.create!(name: name, nodes: nodes, connections: connections, created_by: actor)
      version = workflow.initial_snapshot!(user: actor)
      workflow.publish!(user: actor)
      WorkflowDependencyIndexer.call(workflow.reload, version: version)
      Workflow::Action::ExpireCaches.call
      workflow
    end

    def node(id:, type:, name:, position:, parameters: {})
      {
        "id" => id,
        "type" => type,
        "typeVersion" => "1.0",
        "name" => name,
        "parameters" => parameters,
        "credentials" => {
        },
        "webhookId" => nil,
        "position" => position,
      }
    end

    def actor
      @actor ||= User.where(admin: true).order(:id).first || Discourse.system_user
    end
  end
end
