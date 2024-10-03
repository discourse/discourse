# frozen_string_literal: true

RSpec.describe Jobs::RunProblemChecks do
  around do |example|
    ProblemCheck::ScheduledCheck =
      Class.new(ProblemCheck) do
        self.perform_every = 30.minutes

        def call = []
      end

    ProblemCheck::NonScheduledCheck = Class.new(ProblemCheck) { def call = [] }

    ProblemCheck::DisabledCheck =
      Class.new(ProblemCheck) do
        self.perform_every = 30.minutes
        self.enabled = false

        def call = []
      end

    stub_const(
      ProblemCheck,
      "CORE_PROBLEM_CHECKS",
      [ProblemCheck::ScheduledCheck, ProblemCheck::NonScheduledCheck, ProblemCheck::DisabledCheck],
      &example
    )

    ProblemCheck.send(:remove_const, "ScheduledCheck")
    ProblemCheck.send(:remove_const, "NonScheduledCheck")
    ProblemCheck.send(:remove_const, "DisabledCheck")
  end

  context "when the tracker determines the check is ready to run" do
    before do
      ProblemCheckTracker.create!(identifier: "scheduled_check", next_run_at: 5.minutes.ago)
    end

    it "schedules the individual scheduled checks" do
      expect_enqueued_with(
        job: :run_problem_check,
        args: {
          check_identifier: "scheduled_check",
        },
      ) { described_class.new.execute([]) }
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

  context "when dealing with a disabled check" do
    before { ProblemCheckTracker.create!(identifier: "disabled_check", next_run_at: nil) }

    it "does not schedule any check" do
      expect_not_enqueued_with(
        job: :run_problem_check,
        args: {
          check_identifier: "disabled_check",
        },
      ) { described_class.new.execute([]) }
    end
  end

  context "when dealing with an uninstalled check" do
    before { ProblemCheckTracker.create!(identifier: "uninstalled_check", next_run_at: nil) }

    it "does not schedule any check" do
      expect_not_enqueued_with(
        job: :run_problem_check,
        args: {
          check_identifier: "uninstalled_check",
        },
      ) { described_class.new.execute([]) }
    end
  end
end
