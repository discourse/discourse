# frozen_string_literal: true

require 'rails_helper'

describe Jobs::ProblemChecks do
  before do
    AdminDashboardData.reset_problem_checks
  end

  after do
    Discourse.redis.flushdb
  end

  it "runs the problem check that has been added and adds the messages to the load_found_scheduled_check_problems array" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier) do
      AdminDashboardData::Problem.maybe_create("big problem")
    end

    execute_job_class_with_args
    problems = AdminDashboardData.load_found_scheduled_check_problems
    expect(problems.count).to eq(1)
    expect(problems.first).to be_a(AdminDashboardData::Problem)
    expect(problems.first.to_s).to eq("big problem")
  end

  it "can handle the problem check returning multiple problems" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier) do
      [
        AdminDashboardData::Problem.maybe_create("big problem"),
        AdminDashboardData::Problem.maybe_create("yuge problem", priority: "high", identifier: "config_is_a_mess")
      ]
    end

    execute_job_class_with_args
    problems = AdminDashboardData.load_found_scheduled_check_problems
    expect(problems.count).to eq(2)
  end

  it "does not add the same problem twice if the identifier already exists" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier) do
      [
        AdminDashboardData::Problem.maybe_create("yuge problem", priority: "high", identifier: "config_is_a_mess"),
        AdminDashboardData::Problem.maybe_create("nasty problem", priority: "high", identifier: "config_is_a_mess")
      ]
    end

    execute_job_class_with_args
    problems = AdminDashboardData.load_found_scheduled_check_problems
    expect(problems.count).to eq(1)
  end

  it "starts with a blank slate every time the checks are run to avoid duplicate problems and to clear no longer firing problems" do
    problem_should_fire = true
    AdminDashboardData.add_scheduled_problem_check(:test_identifier) do
      if problem_should_fire
        problem_should_fire = false
        AdminDashboardData::Problem.maybe_create("yuge problem", priority: "high")
      end
    end

    execute_job_class_with_args
    expect(AdminDashboardData.load_found_scheduled_check_problems.count).to eq(1)
    execute_job_class_with_args
    expect(AdminDashboardData.load_found_scheduled_check_problems.count).to eq(0)
  end

  it "handles errors from a troublesome check and proceeds with the rest" do
    AdminDashboardData.add_scheduled_problem_check(:test_identifier) do
      raise StandardError.new("something went wrong")
      AdminDashboardData::Problem.maybe_create("polling issue")
    end
    AdminDashboardData.add_scheduled_problem_check(:test_identifier_2) do
      AdminDashboardData::Problem.maybe_create("yuge problem", priority: "high")
    end

    execute_job_class_with_args
    expect(AdminDashboardData.load_found_scheduled_check_problems.count).to eq(1)
  end
end
