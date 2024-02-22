# frozen_string_literal: true

RSpec.describe Jobs::ProblemChecks do
  before { ProblemCheck::FooBar = Class.new(ProblemCheck) }

  after do
    Discourse.redis.flushdb
    AdminDashboardData.reset_problem_checks

    ProblemCheck.send(:remove_const, "FooBar")
  end

  class TestCheck
    def self.max_retries = 0
    def self.retry_wait = 0.seconds
  end

  it "starts with a blank slate every time the checks are run to avoid duplicate problems and to clear no longer firing problems" do
    problem_should_fire = true
    AdminDashboardData.reset_problem_checks
    AdminDashboardData.add_scheduled_problem_check(:test_identifier, TestCheck) do
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

  it "schedules the individual checks" do
    expect_enqueued_with(job: :problem_check, args: { check_identifier: "foo_bar" }) do
      described_class.new.execute([])
    end
  end
end
