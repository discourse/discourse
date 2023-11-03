# frozen_string_literal: true

RSpec.describe Jobs::ProblemChecks do
  before { Jobs.run_immediately! }

  after do
    Discourse.redis.flushdb
    AdminDashboardData.reset_problem_checks
  end

  it "starts with a blank slate every time the checks are run to avoid duplicate problems and to clear no longer firing problems" do
    problem_should_fire = true
    AdminDashboardData.reset_problem_checks
    AdminDashboardData.add_scheduled_problem_check(:test_identifier) do
      if problem_should_fire
        problem_should_fire = false
        AdminDashboardData::Problem.new("yuge problem", priority: "high")
      end
    end

    described_class.new.execute(nil)
    expect(AdminDashboardData.load_found_scheduled_check_problems.count).to eq(1)
    described_class.new.execute(nil)
    expect(AdminDashboardData.load_found_scheduled_check_problems.count).to eq(0)
  end
end
