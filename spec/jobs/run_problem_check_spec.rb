# frozen_string_literal: true

RSpec.describe Jobs::RunProblemCheck do
  after { Discourse.redis.flushdb }

  context "when there are problems" do
    around do |example|
      ProblemCheck::TestCheck =
        Class.new(ProblemCheck) do
          self.perform_every = 30.minutes
          self.max_retries = 0

          def call
            [
              ProblemCheck::Problem.new("Big problem"),
              ProblemCheck::Problem.new(
                "Yuge problem",
                priority: "high",
                identifier: "config_is_a_mess",
              ),
            ]
          end
        end

      stub_const(ProblemCheck, "CORE_PROBLEM_CHECKS", [ProblemCheck::TestCheck], &example)

      ProblemCheck.send(:remove_const, "TestCheck")
    end

    it "updates the problem check tracker" do
      expect {
        described_class.new.execute(check_identifier: "test_check", retry_count: 0)
      }.to change { ProblemCheckTracker.failing.count }.by(1)
    end
  end

  context "when there are retries remaining" do
    around do |example|
      ProblemCheck::TestCheck =
        Class.new(ProblemCheck) do
          self.perform_every = 30.minutes
          self.max_retries = 2

          def call
            [ProblemCheck::Problem.new("Yuge problem")]
          end
        end

      stub_const(ProblemCheck, "CORE_PROBLEM_CHECKS", [ProblemCheck::TestCheck], &example)

      ProblemCheck.send(:remove_const, "TestCheck")
    end

    it "does not yet update the problem check tracker" do
      expect {
        described_class.new.execute(check_identifier: "test_check", retry_count: 1)
      }.not_to change { ProblemCheckTracker.where("blips > ?", 0).count }
    end

    it "schedules a retry" do
      expect_enqueued_with(
        job: :run_problem_check,
        args: {
          check_identifier: "test_check",
          retry_count: 1,
        },
      ) { described_class.new.execute(check_identifier: "test_check") }
    end
  end

  context "when there are no retries remaining" do
    around do |example|
      ProblemCheck::TestCheck =
        Class.new(ProblemCheck) do
          self.perform_every = 30.minutes
          self.max_retries = 1

          def call
            [ProblemCheck::Problem.new("Yuge problem")]
          end
        end

      stub_const(ProblemCheck, "CORE_PROBLEM_CHECKS", [ProblemCheck::TestCheck], &example)

      ProblemCheck.send(:remove_const, "TestCheck")
    end

    it "updates the problem check tracker" do
      expect {
        described_class.new.execute(check_identifier: "test_check", retry_count: 1)
      }.to change { ProblemCheckTracker.where("blips > ?", 0).count }.by(1)
    end

    it "does not schedule a retry" do
      expect_not_enqueued_with(job: :run_problem_check) do
        described_class.new.execute(check_identifier: "test_check", retry_count: 1)
      end
    end
  end
end
