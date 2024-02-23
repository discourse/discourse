# frozen_string_literal: true

RSpec.describe Jobs::ProblemChecks do
  before do
    ::ProblemCheck::ScheduledCheck =
      Class.new(ProblemCheck) do
        self.perform_every = 30.minutes

        def call = []
      end

    ::ProblemCheck::NonScheduledCheck = Class.new(ProblemCheck) { def call = [] }
  end

  after do
    Discourse.redis.flushdb
    AdminDashboardData.reset_problem_checks

    ProblemCheck.send(:remove_const, "ScheduledCheck")
    ProblemCheck.send(:remove_const, "NonScheduledCheck")
  end

  it "schedules the individual scheduled checks" do
    expect_enqueued_with(job: :problem_check, args: { check_identifier: "scheduled_check" }) do
      described_class.new.execute([])
    end
  end

  it "does not schedule non-scheduled checks" do
    expect_not_enqueued_with(
      job: :problem_check,
      args: {
        check_identifier: "non_scheduled_check",
      },
    ) { described_class.new.execute([]) }
  end

  it "does not schedule non-scheduled checks" do
    expect_not_enqueued_with(
      job: :problem_check,
      args: {
        check_identifier: "non_scheduled_check",
      },
    ) { described_class.new.execute([]) }
  end
end
