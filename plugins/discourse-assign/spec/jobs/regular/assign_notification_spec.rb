# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::AssignNotification do
  describe "#execute" do
    subject(:execute_job) { described_class.new.execute(args) }

    let(:args) { { assignment_id: assignment_id } }

    context "when `assignment_id` is not provided" do
      let(:args) { {} }

      it "raises an error" do
        expect { execute_job }.to raise_error(Discourse::InvalidParameters, "assignment_id")
      end
    end

    context "when `assignment_id` is provided" do
      let(:assignment_id) { Fabricate(:topic_assignment).id }
      let(:assignment) { stub("assignment").responds_like_instance_of(Assignment) }

      before { Assignment.stubs(:find).with(assignment_id).returns(assignment) }

      it "creates missing notifications for the provided assignment" do
        assignment.expects(:create_missing_notifications!)
        execute_job
      end

      it "does not create notifications if assignment is silenced" do
        SilencedAssignment.stubs(:exists?).with(assignment_id: assignment_id).returns(true)
        assignment.expects(:create_missing_notifications!).never
        execute_job
      end
    end
  end
end
