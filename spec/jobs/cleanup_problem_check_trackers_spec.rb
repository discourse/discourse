# frozen_string_literal: true

RSpec.describe Jobs::CleanupProblemCheckTrackers do
  around do |example|
    ProblemCheck::MultiTargetCheck =
      Class.new(ProblemCheck) do
        self.perform_every = 30.minutes
        self.targets = -> { %w[foo bar] }
      end

    stub_const(ProblemCheck, "CORE_PROBLEM_CHECKS", [ProblemCheck::MultiTargetCheck], &example)

    ProblemCheck.send(:remove_const, "MultiTargetCheck")
  end

  context "when a tracker has an outdated target" do
    before do
      ProblemCheckTracker.create!(identifier: "multi_target_check", target: "foo").problem!
      ProblemCheckTracker.create!(identifier: "multi_target_check", target: "bar").problem!
      ProblemCheckTracker.create!(identifier: "multi_target_check", target: "baz").problem!
    end

    it "deletes trackers with non-existing targets together with any admin notices" do
      expect { described_class.new.execute([]) }.to change {
        ProblemCheckTracker.pluck(:target)
      }.from(contain_exactly("foo", "bar", "baz")).to(contain_exactly("foo", "bar")).and change {
              AdminNotice.count
            }.by(-1)
    end
  end
end
