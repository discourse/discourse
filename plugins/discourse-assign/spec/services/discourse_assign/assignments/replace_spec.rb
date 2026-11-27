# frozen_string_literal: true

RSpec.describe DiscourseAssign::Assignments::Replace do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to allow_value([]).for(:assignments) }
    it { is_expected.not_to allow_values(nil, "invalid", ["invalid"]).for(:assignments) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:first_assignee, :moderator)
    fab!(:second_assignee, :moderator)
    fab!(:topic, :topic_with_op)

    let(:params) { { topic_id: topic.id, assignments: assignments } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:assignments) do
      [{ username: first_assignee.username }, { username: second_assignee.username }]
    end

    before do
      SiteSetting.assign_enabled = true
      SiteSetting.assign_allow_multiple_topic_assignees = true
    end

    context "when the contract is invalid" do
      let(:params) { { topic_id: nil, assignments: [] } }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic does not exist" do
      let(:params) { { topic_id: 0, assignments: assignments } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when the acting user cannot assign" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:can_assign) }
    end

    context "when multiple assignments are disabled" do
      before { SiteSetting.assign_allow_multiple_topic_assignees = false }

      it { is_expected.to fail_a_step(:replace_assignments) }
    end

    context "with a stale editor version" do
      let(:params) { super().merge(expected_version: "outdated") }

      it { is_expected.to fail_a_step(:replace_assignments) }
    end

    context "with duplicate assignees" do
      let(:assignments) do
        [{ username: first_assignee.username }, { username: first_assignee.username }]
      end

      it "rejects the complete set" do
        expect(result).to fail_a_step(:replace_assignments)
        expect(topic.assignments).to be_empty
      end
    end

    context "with two groups" do
      fab!(:first_group) { Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone]) }
      fab!(:second_group) { Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone]) }

      let(:assignments) { [{ group_name: first_group.name }, { group_name: second_group.name }] }

      before { SiteSetting.assign_allowed_on_groups += "|#{first_group.id}|#{second_group.id}" }

      it "rejects the complete set" do
        expect(result).to fail_a_step(:replace_assignments)
        expect(topic.assignments).to be_empty
      end
    end

    context "when post assignments consume the combined limit" do
      before do
        SiteSetting.assign_max_assignments_per_topic = 2
        Fabricate(:post_assignment, topic: topic, assigned_to: first_assignee)
      end

      it "rejects adding more direct assignments than the remaining capacity" do
        expect(result).to fail_a_step(:replace_assignments)
        expect(topic.assignments).to be_empty
      end
    end

    context "with an assignment ID from another topic" do
      let!(:other_assignment) { Fabricate(:topic_assignment, assigned_to: first_assignee) }
      let(:assignments) { [{ id: other_assignment.id, username: first_assignee.username }] }

      it "preserves the other topic's assignment" do
        expect(result).to fail_a_step(:replace_assignments)
        expect(other_assignment.reload).to be_active
        expect(topic.assignments).to be_empty
      end
    end

    context "with eligible assignees" do
      it "persists separate direct assignments" do
        expect(result).to run_successfully
        expect(topic.assignments.active.pluck(:assigned_to_id)).to contain_exactly(
          first_assignee.id,
          second_assignee.id,
        )
      end

      it "preserves assignments on individual posts" do
        post_assignment = Fabricate(:post_assignment, topic: topic, assigned_to: first_assignee)

        expect(result).to run_successfully
        expect(post_assignment.reload).to be_active
        expect(post_assignment.target_type).to eq("Post")
      end
    end

    context "with users and one eligible group" do
      fab!(:group) { Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone]) }

      let(:assignments) { super() + [{ group_name: group.name }] }

      before do
        group.add(first_assignee)
        SiteSetting.assign_allowed_on_groups += "|#{group.id}"
      end

      it "persists direct and group responsibilities separately" do
        expect(result).to run_successfully
        expect(topic.assignments.active.map(&:assigned_to)).to contain_exactly(
          first_assignee,
          second_assignee,
          group,
        )
      end
    end

    context "with a retained assignee" do
      let!(:existing_assignment) do
        Fabricate(
          :topic_assignment,
          topic: topic,
          assigned_to: first_assignee,
          assigned_by_user: acting_user,
          note: "Review the references",
        )
      end
      let(:assignments) do
        [
          { id: existing_assignment.id, username: first_assignee.username, note: "" },
          { username: second_assignee.username, note: "Check the publication details" },
        ]
      end

      it "keeps its identity and clears its note" do
        original_created_at = existing_assignment.created_at

        expect(result).to run_successfully
        expect(existing_assignment.reload.note).to be_blank
        expect(existing_assignment.created_at).to eq_time(original_created_at)
        expect(existing_assignment.assigned_by_user).to eq(acting_user)
        expect(topic.posts.where(action_code: "note_change").count).to eq(1)
      end
    end

    context "with a per-assignee status change" do
      let!(:existing_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: first_assignee, status: "New")
      end
      let(:assignments) do
        [{ id: existing_assignment.id, username: first_assignee.username, status: "Done" }]
      end

      before { SiteSetting.enable_assign_status = true }

      it "updates the existing assignment without changing its identity" do
        expect(result).to run_successfully
        expect(existing_assignment.reload.status).to eq("Done")
      end
    end

    context "with an invalid assignment status" do
      let(:assignments) { [{ username: first_assignee.username, status: "Invalid status" }] }

      before { SiteSetting.enable_assign_status = true }

      it "rejects the assignment without persisting it" do
        expect(result).to fail_a_step(:replace_assignments)
        expect(topic.assignments).to be_empty
      end
    end

    context "when multiple assignments are disabled after assignments exist" do
      let!(:first_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: first_assignee)
      end
      let!(:second_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: second_assignee)
      end
      let(:assignments) do
        [
          { id: first_assignment.id, username: first_assignee.username, note: "Updated note" },
          { id: second_assignment.id, username: second_assignee.username },
        ]
      end

      before { SiteSetting.assign_allow_multiple_topic_assignees = false }

      it "allows details editing without discarding any existing assignee" do
        expect(result).to run_successfully
        expect(first_assignment.reload.note).to eq("Updated note")
        expect(topic.assignments.reload).to contain_exactly(first_assignment, second_assignment)
      end
    end

    context "when removing an assignment after multiple assignments are disabled" do
      let!(:first_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: first_assignee)
      end
      let!(:second_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: second_assignee)
      end
      let(:assignments) { [{ id: first_assignment.id, username: first_assignee.username }] }

      before { SiteSetting.assign_allow_multiple_topic_assignees = false }

      it "removes only the requested assignment" do
        expect(result).to run_successfully
        expect(topic.assignments.reload).to contain_exactly(first_assignment)
      end
    end

    context "when reactivating another assignee after multiple assignments are disabled" do
      let!(:first_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: first_assignee)
      end
      let!(:second_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: second_assignee, active: false)
      end
      let(:assignments) do
        [
          { id: first_assignment.id, username: first_assignee.username },
          { id: second_assignment.id, username: second_assignee.username },
        ]
      end

      before { SiteSetting.assign_allow_multiple_topic_assignees = false }

      it "keeps the second assignment inactive" do
        expect(result).to fail_a_step(:replace_assignments)
        expect(first_assignment.reload).to be_active
        expect(second_assignment.reload).not_to be_active
      end
    end

    context "with an empty desired set" do
      let!(:existing_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: first_assignee)
      end
      let!(:post_assignment) { Fabricate(:post_assignment, topic: topic) }
      let(:assignments) { [] }

      it "clears direct assignments and preserves post assignments" do
        expect(result).to run_successfully
        expect(topic.assignments.active).to be_empty
        expect(post_assignment.reload).to be_active
      end
    end

    context "with a retained assignment whose details are omitted" do
      let!(:existing_assignment) do
        Fabricate(
          :topic_assignment,
          topic: topic,
          assigned_to: first_assignee,
          assigned_by_user: second_assignee,
          note: "Keep the existing note",
        )
      end
      let(:assignments) { [{ id: existing_assignment.id, username: first_assignee.username }] }

      it "preserves the existing details and assigner" do
        expect(result).to run_successfully
        expect(existing_assignment.reload.note).to eq("Keep the existing note")
        expect(existing_assignment.assigned_by_user).to eq(second_assignee)
      end
    end

    context "with an omitted inactive user assignment" do
      let!(:inactive_assignment) do
        Fabricate(
          :topic_assignment,
          topic: topic,
          assigned_to: second_assignee,
          active: false,
          note: "Retain for reopening",
        )
      end
      let(:assignments) { [{ username: first_assignee.username }] }

      it "preserves the inactive assignment and its details" do
        expect(result).to run_successfully
        expect(inactive_assignment.reload).not_to be_active
        expect(inactive_assignment.note).to eq("Retain for reopening")
      end
    end

    context "when an assignee fails validation after another change" do
      fab!(:ineligible_assignee, :user)

      let!(:existing_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: first_assignee)
      end
      let(:assignments) do
        [{ username: second_assignee.username }, { username: ineligible_assignee.username }]
      end
      let(:messages) { MessageBus.track_publish("/staff/topic-assignment") { result } }

      it "rolls back the complete replacement without publishing an update" do
        expect(messages).to be_empty
        expect(result).to fail_a_step(:replace_assignments)
        expect(topic.assignments.reload).to contain_exactly(existing_assignment)
      end
    end
  end
end
