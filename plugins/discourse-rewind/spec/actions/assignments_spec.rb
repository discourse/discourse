# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::Assignments do
  fab!(:user)

  before { SiteSetting.assign_enabled = true }

  describe ".call" do
    it "returns nothing when no assignment was made during the year" do
      Fabricate(:topic_assignment, assigned_to: user, created_at: Date.new(2020, 6, 1))

      expect(call_report).to be_nil
    end

    it "returns the assignment statistics" do
      assigned_at = random_datetime
      Fabricate(
        :topic_assignment,
        assigned_to: user,
        created_at: assigned_at,
        updated_at: assigned_at,
      )
      Fabricate(
        :topic_assignment,
        assigned_to: user,
        topic: Fabricate(:topic, closed: true),
        created_at: assigned_at,
        updated_at: assigned_at,
      )
      Fabricate(:topic_assignment, assigned_to: user, active: false, created_at: assigned_at)
      Fabricate(:topic_assignment, assigned_by_user: user, created_at: assigned_at)

      expect(call_report[:data]).to eq(
        total_assigned: 3,
        completed: 2,
        pending: 1,
        assigned_by_user: 1,
        completion_rate: 66.7,
      )
    end
  end
end
