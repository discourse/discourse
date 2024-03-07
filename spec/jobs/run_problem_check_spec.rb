# frozen_string_literal: true

RSpec.describe Jobs::RunProblemCheck do
  after do
    Discourse.redis.flushdb

    ProblemCheck.send(:remove_const, "TestCheck")
  end

  context "when there are problems" do
    before do
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
    end

    it "adds the messages to the Redis problems array" do
      described_class.new.execute(check_identifier: :test_check)

      problems = AdminDashboardData.load_found_scheduled_check_problems

      expect(problems.map(&:to_s)).to contain_exactly("Big problem", "Yuge problem")
    end
  end

  context "with multiple problems with the same identifier" do
    before do
      ProblemCheck::TestCheck =
        Class.new(ProblemCheck) do
          self.perform_every = 30.minutes
          self.max_retries = 0

          def call
            [
              ProblemCheck::Problem.new(
                "Yuge problem",
                priority: "high",
                identifier: "config_is_a_mess",
              ),
              ProblemCheck::Problem.new(
                "Nasty problem",
                priority: "high",
                identifier: "config_is_a_mess",
              ),
            ]
          end
        end
    end

    it "does not add the same problem twice" do
      described_class.new.execute(check_identifier: :test_check)

      problems = AdminDashboardData.load_found_scheduled_check_problems

      expect(problems.map(&:to_s)).to match_array(["Yuge problem"])
    end
  end

  context "when there are retries remaining" do
    before do
      ProblemCheck::TestCheck =
        Class.new(ProblemCheck) do
          self.perform_every = 30.minutes
          self.max_retries = 2

          def call
            [ProblemCheck::Problem.new("Yuge problem")]
          end
        end
    end

    it "does not yet update the problem check tracker" do
      expect {
        described_class.new.execute(check_identifier: :test_check, retry_count: 1)
      }.not_to change { ProblemCheckTracker.where("blips > ?", 0).count }
    end

    it "schedules a retry" do
      expect_enqueued_with(
        job: :problem_check,
        args: {
          check_identifier: :test_check,
          retry_count: 1,
        },
      ) { described_class.new.execute(check_identifier: :test_check) }
    end
  end

  context "when there are no retries remaining" do
    before do
      ProblemCheck::TestCheck =
        Class.new(ProblemCheck) do
          self.perform_every = 30.minutes
          self.max_retries = 1

          def call
            [ProblemCheck::Problem.new("Yuge problem")]
          end
        end
    end

    it "updates the problem check tracker" do
      expect {
        described_class.new.execute(check_identifier: :test_check, retry_count: 1)
      }.to change { ProblemCheckTracker.where("blips > ?", 0).count }.by(1)
    end

    it "does not schedule a retry" do
      expect_not_enqueued_with(job: :problem_check) do
        described_class.new.execute(check_identifier: :test_check, retry_count: 1)
      end
    end
  end

  context "when the check unexpectedly errors out" do
    before do
      ProblemCheck::TestCheck =
        Class.new(ProblemCheck) do
          self.max_retries = 1

          def call
            raise StandardError.new("Something went wrong")
          end
        end
    end

    it "does not add a problem to the Redis array" do
      described_class.new.execute(check_identifier: :test_check)

      expect(AdminDashboardData.load_found_scheduled_check_problems).to be_empty
    end
  end
end
