# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:admin)
  fab!(:user)

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def serialized(target)
    JSON.parse(described_class.new(target, scope: Guardian.new(target), root: false).to_json)
  end

  def index_modal_workflow
    graph =
      build_workflow_graph do |g|
        g.node "t1", "trigger:manual"
        g.node "m1",
               "action:modal",
               configuration: {
                 "title" => "Approve?",
                 "buttons" => {
                   "values" => [{ "label" => "Approve", "value" => "approve" }],
                 },
               }
        g.chain "t1", "m1"
      end
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    version = workflow.workflow_versions.find_by(version_id: workflow.version_id)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: version)
  end

  describe "discourse_workflows_user_modal_last_id" do
    it "is omitted when no workflow uses a modal node" do
      expect(serialized(user)).not_to have_key("discourse_workflows_user_modal_last_id")
    end

    it "is the channel's last id when a workflow uses a modal node" do
      index_modal_workflow
      channel = DiscourseWorkflows::Nodes::Modal::V1.user_channel(user.id)
      MessageBus.publish(channel, { type: "show_modal" }, user_ids: [user.id])

      payload = serialized(user)

      expect(payload["discourse_workflows_user_modal_last_id"]).to eq(MessageBus.last_id(channel))
    end
  end
end
