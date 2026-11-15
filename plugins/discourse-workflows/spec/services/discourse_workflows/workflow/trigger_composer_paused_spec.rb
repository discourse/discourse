# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::TriggerComposerPaused do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:draft_key) }
    it { is_expected.to validate_presence_of(:session_id) }
    it { is_expected.to validate_inclusion_of(:composer_action).in_array(%w[create_topic reply]) }

    it "requires a topic for replies" do
      contract = described_class.new(composer_action: "reply")
      expect(contract).to validate_presence_of(:topic_id)
    end

    it "limits the text to what a post allows" do
      SiteSetting.max_post_length = 20

      expect(described_class.new(raw: "a" * 21).tap(&:valid?).errors[:raw]).to be_present
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic)

    let(:configuration) { { "phrases" => ["Magic words", "food stand"] } }
    let!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:composer_paused", configuration: configuration
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    let(:params) do
      {
        draft_key: "new_topic",
        session_id: "session-1",
        composer_action: "create_topic",
        title: "Lunch review",
        raw: "Meet me at the food stand",
      }
    end
    let(:dependencies) { { guardian: user.guardian } }

    before { DiscourseWorkflows::WorkflowDependency.clear_cache! }

    context "when contract is invalid" do
      let(:params) { super().except(:draft_key) }

      it { is_expected.to fail_a_contract }
    end

    shared_examples "doesn't fire" do
      it "enqueues nothing" do
        expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
        expect(result).to run_successfully
      end
    end

    context "when the workflow is unpublished" do
      before { unpublish_workflow!(workflow) }

      include_examples "doesn't fire"
    end

    context "when the trigger fires on draft saves" do
      let(:configuration) { super().merge("fire_on" => "draft_saved") }

      include_examples "doesn't fire"
    end

    context "when the user is in none of the trigger's groups" do
      let(:configuration) { super().merge("group_ids" => [Fabricate(:group).id]) }

      include_examples "doesn't fire"
    end

    context "when replying to a personal message" do
      fab!(:pm) { Fabricate(:private_message_topic, user:) }

      let(:params) do
        super().merge(composer_action: "reply", topic_id: pm.id, draft_key: "topic_#{pm.id}")
      end

      include_examples "doesn't fire"
    end

    context "when no phrase matches" do
      let(:params) { super().merge(raw: "[quote=\"sam, post:1, topic:2\"]food stand[/quote]") }

      include_examples "doesn't fire"
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "enqueues the workflow with the matched phrases" do
        result

        job_args = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first
        expect(job_args).to include(
          "workflow_id" => workflow.id,
          "trigger_node_id" => "trigger-1",
          "user_id" => user.id,
        )
        expect(job_args["trigger_data"]["composer"]).to include(
          "draft_key" => "new_topic",
          "title" => "Lunch review",
          "matched_phrases" => ["food stand"],
        )
      end
    end

    context "when the phrases already fired in this session" do
      before { described_class.call(params:, **dependencies) }

      include_examples "doesn't fire"
    end

    context "when several workflows match" do
      let!(:other_workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:composer_paused", configuration: {}
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      it "fires each of them" do
        result

        expect(
          Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |job|
            job["args"].first["workflow_id"]
          end,
        ).to contain_exactly(workflow.id, other_workflow.id)
      end

      it "fails when the rate limit runs out, and fires the rest once it allows" do
        RateLimiter.enable
        stub_const(DiscourseWorkflows::ComposerPausedClaims, "RATE_LIMIT", 1) do
          expect(result).to fail_a_step(:fire_triggers)
        end
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

        expect(described_class.call(params:, **dependencies)).to run_successfully
        expect(
          Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |job|
            job["args"].first["workflow_id"]
          end,
        ).to contain_exactly(workflow.id, other_workflow.id)
      end
    end

    context "when the run can't be recorded" do
      before do
        allow_any_instance_of(RateLimiter).to receive(:performed!).and_return(false)
        described_class.call(params:, **dependencies)
      end

      it "gives the phrase back, so it fires later" do
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty

        allow_any_instance_of(RateLimiter).to receive(:performed!).and_call_original
        result

        expect(
          Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.sole["args"].first["trigger_data"][
            "composer"
          ][
            "matched_phrases"
          ],
        ).to eq(["food stand"])
      end
    end

    context "when a new phrase matches in the same session" do
      before { described_class.call(params: params.merge(raw: "food stand"), **dependencies) }

      let(:params) { super().merge(raw: "food stand and the Magic words") }

      it "only sends the new phrase" do
        result

        expect(
          Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"][
            "composer"
          ][
            "matched_phrases"
          ],
        ).to eq(["Magic words"])
      end
    end

    context "when the composer was reopened" do
      before { described_class.call(params: params.merge(session_id: "session-1"), **dependencies) }

      let(:params) { super().merge(session_id: "session-2") }

      it { is_expected.to run_successfully }
    end

    context "when the trigger has no phrases" do
      let(:configuration) { {} }
      let(:params) { super().merge(raw: "Anything at all") }

      it "enqueues the workflow" do
        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)
        expect(result).to run_successfully
      end
    end

    context "when replying to a topic" do
      let(:params) do
        super().merge(
          composer_action: "reply",
          topic_id: topic.id,
          draft_key: "topic_#{topic.id}",
          reply_to_post_number: 1,
        )
      end

      it "includes the topic" do
        result

        trigger_data =
          Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first["trigger_data"]
        expect(trigger_data["topic"]).to include("id" => topic.id)
        expect(trigger_data["composer"]).to include(
          "session_id" => "session-1",
          "topic_id" => topic.id,
          "reply_to_post_number" => 1,
        )
      end
    end
  end
end
