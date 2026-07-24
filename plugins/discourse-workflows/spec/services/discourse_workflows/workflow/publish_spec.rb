# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Publish do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user, :admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user) }

    let(:params) { { workflow_id: workflow.id } }
    let(:dependencies) { { guardian: user.guardian } }

    context "when workflow is not found" do
      let(:params) { { workflow_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when user cannot manage workflows" do
      fab!(:non_admin, :user)

      let(:dependencies) { { guardian: non_admin.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when workflow has no matching snapshot for its current versionId" do
      before { workflow.workflow_versions.delete_all }

      it { is_expected.to fail_to_find_a_model(:workflow_version) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "publishes the workflow's current version" do
        result
        expect(workflow.reload.active_version_id).to eq(workflow.version_id)
      end

      it_behaves_like "expires workflow caches"

      context "when another active workflow already owns the same webhook route" do
        fab!(:owner) do
          graph =
            build_workflow_graph do |g|
              g.node "webhook-1",
                     "trigger:webhook",
                     configuration: {
                       "path" => "shared-hook",
                       "http_method" => "POST",
                     }
            end
          Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
        end

        before do
          version = owner.workflow_versions.find_by(version_id: owner.version_id)
          DiscourseWorkflows::Webhook::Action::ActivateWebhooks.call(
            workflow: owner,
            workflow_version: version,
          )

          conflicting_graph =
            build_workflow_graph do |g|
              g.node "webhook-1",
                     "trigger:webhook",
                     configuration: {
                       "path" => "shared-hook",
                       "http_method" => "POST",
                     }
            end
          workflow.update!(
            nodes: conflicting_graph[:nodes],
            connections: conflicting_graph[:connections],
          )
          workflow.snapshot!(user: user)
        end

        it { is_expected.to fail_a_step(:activate_triggers) }

        it "rolls back the publish so active_version_id stays nil" do
          result
          expect(workflow.reload.active_version_id).to be_nil
        end
      end

      it "prunes trigger_state for nodes removed from the published draft" do
        last_triggered_at = 1.minute.ago.iso8601
        graph = build_workflow_graph { |g| g.node "kept-trigger", "trigger:schedule" }
        workflow.update!(
          nodes: graph[:nodes],
          connections: graph[:connections],
          trigger_state: {
            "kept-trigger" => {
              "last_triggered_at" => last_triggered_at,
            },
            "removed-trigger" => {
              "triggered_occurrences" => ["removed-key"],
            },
          },
        )
        workflow.snapshot!(user: user)

        result

        expect(workflow.reload.trigger_state).to eq(
          "kept-trigger" => {
            "last_triggered_at" => last_triggered_at,
          },
        )
      end

      it "leaves user-facing static_data untouched on publish" do
        graph = build_workflow_graph { |g| g.node "kept-trigger", "trigger:schedule" }
        workflow.update!(
          nodes: graph[:nodes],
          connections: graph[:connections],
          static_data: {
            "global" => {
              "tenant_id" => "acme",
            },
            "node:Kept trigger" => {
              "cursor" => "k-1",
            },
            "node:Removed Node" => {
              "cursor" => "r-1",
            },
          },
        )
        workflow.snapshot!(user: user)

        result

        expect(workflow.reload.static_data).to eq(
          "global" => {
            "tenant_id" => "acme",
          },
          "node:Kept trigger" => {
            "cursor" => "k-1",
          },
          "node:Removed Node" => {
            "cursor" => "r-1",
          },
        )
      end
    end
  end
end
