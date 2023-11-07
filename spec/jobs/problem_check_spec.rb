# frozen_string_literal: true

RSpec.describe Jobs::ProblemCheck do
  after do
    Discourse.redis.flushdb
    AdminDashboardData.reset_problem_checks
  end

  class TestCheck
    def self.max_retries = 0
    def self.retry_wait = 30.seconds
  end

  it "runs the scheduled problem check that has been added and adds the messages to the load_found_scheduled_check_problems array" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier, TestCheck) do
      AdminDashboardData::Problem.new("big problem")
    end

    described_class.new.execute(check_identifier: :test_identifier)
    problems = AdminDashboardData.load_found_scheduled_check_problems
    expect(problems.count).to eq(1)
    expect(problems.first).to be_a(AdminDashboardData::Problem)
    expect(problems.first.to_s).to eq("big problem")
  end

  it "can handle the problem check returning multiple problems" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier, TestCheck) do
      [
        AdminDashboardData::Problem.new("big problem"),
        AdminDashboardData::Problem.new(
          "yuge problem",
          priority: "high",
          identifier: "config_is_a_mess",
        ),
      ]
    end

    described_class.new.execute(check_identifier: :test_identifier)
    problems = AdminDashboardData.load_found_scheduled_check_problems
    expect(problems.map(&:to_s)).to match_array(["big problem", "yuge problem"])
  end

  it "does not add the same problem twice if the identifier already exists" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier, TestCheck) do
      [
        AdminDashboardData::Problem.new(
          "yuge problem",
          priority: "high",
          identifier: "config_is_a_mess",
        ),
        AdminDashboardData::Problem.new(
          "nasty problem",
          priority: "high",
          identifier: "config_is_a_mess",
        ),
      ]
    end

    described_class.new.execute(check_identifier: :test_identifier)
    problems = AdminDashboardData.load_found_scheduled_check_problems
    expect(problems.map(&:to_s)).to match_array(["yuge problem"])
  end

  it "schedules a retry if there are attempts remaining" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier, TestCheck) do
      AdminDashboardData::Problem.new("big problem")
    end

    TestCheck.stubs(:max_retries).returns(1)

    expect_enqueued_with(
      job: :problem_check,
      args: {
        check_identifier: :test_identifier,
        retry_count: 1,
      },
    ) { described_class.new.execute(check_identifier: :test_identifier) }
  end

  it "does not schedule a retry if there are no more attempts remaining" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier, TestCheck) do
      AdminDashboardData::Problem.new("big problem")
    end

    TestCheck.stubs(:max_retries).returns(1)

    expect_not_enqueued_with(job: :problem_check) do
      described_class.new.execute(check_identifier: :test_identifier, retry_count: 1)
    end
  end

  it "handles errors from a troublesome check" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier, TestCheck) do
      raise StandardError.new("something went wrong")
      AdminDashboardData::Problem.new("polling issue")
    end

    described_class.new.execute(check_identifier: :test_identifier)
    expect(AdminDashboardData.load_found_scheduled_check_problems.count).to eq(0)
  end
end
