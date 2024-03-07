# frozen_string_literal: true

RSpec.describe Jobs::RunProblemChecks do
  before do
    ProblemCheck::ScheduledCheck =
      Class.new(ProblemCheck) do
        self.perform_every = 30.minutes

        def call = []
      end

    ProblemCheck::NonScheduledCheck = Class.new(ProblemCheck) { def call = [] }
  end

  after do
    Discourse.redis.flushdb
    AdminDashboardData.reset_problem_checks

    ProblemCheck.send(:remove_const, "ScheduledCheck")
    ProblemCheck.send(:remove_const, "NonScheduledCheck")
  end

  context "when the tracker determines the check is ready to run" do
    before do
      ProblemCheckTracker.create!(identifier: "scheduled_check", next_run_at: 5.minutes.ago)
    end

    it "schedules the individual scheduled checks" do
      expect_enqueued_with(job: :problem_check, args: { check_identifier: "scheduled_check" }) do
        described_class.new.execute([])
      end
    end
  end

  context "when the tracker determines the check shouldn't run yet" do
    before do
      ProblemCheckTracker.create!(identifier: "scheduled_check", next_run_at: 5.minutes.from_now)
    end

    it "does not schedule any check" do
      expect_not_enqueued_with(
        job: :run_problem_check,
        args: {
          check_identifier: "scheduled_check",
        },
      ) { described_class.new.execute([]) }
    end
  end

  context "when dealing with a non-scheduled check" do
    before { ProblemCheckTracker.create!(identifier: "non_scheduled_check", next_run_at: nil) }

    it "does not schedule any check" do
      expect_not_enqueued_with(
        job: :run_problem_check,
        args: {
          check_identifier: "non_scheduled_check",
        },
      ) { described_class.new.execute([]) }
    end
  end

  it "does not schedule non-scheduled checks" do
    expect_not_enqueued_with(
      job: :run_problem_check,
      args: {
        check_identifier: "non_scheduled_check",
      },
    ) { described_class.new.execute([]) }
  end
end
