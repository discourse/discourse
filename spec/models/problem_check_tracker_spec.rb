# frozen_string_literal: true

RSpec.describe ProblemCheckTracker do
  describe "validations" do
    let(:record) { described_class.new(identifier: "twitter_login") }

    it { expect(record).to validate_presence_of(:identifier) }
    it { expect(record).to validate_uniqueness_of(:identifier).scoped_to(:target) }

    it { expect(record).to validate_numericality_of(:blips).is_greater_than_or_equal_to(0) }
  end

  describe ".[]" do
    before { Fabricate(:problem_check_tracker, identifier: "twitter_login") }

    context "when the problem check tracker already exists" do
      it { expect(described_class[:twitter_login]).not_to be_new_record }
    end

    context "when the problem check tracker doesn't exist yet" do
      it { expect(described_class[:facebook_login]).to be_previously_new_record }
    end
  end

  describe "#check" do
    before do
      Fabricate(:problem_check_tracker, identifier: "twitter_login")
      Fabricate(:problem_check_tracker, identifier: "missing_check")
    end

    context "when the tracker has a corresponding check" do
      it { expect(described_class[:twitter_login].check.new).to be_a(ProblemCheck) }
    end

    context "when the checking logic of the tracker has been removed or renamed" do
      it do
        expect { described_class[:missing_check].check }.to change { described_class.count }.by(-1)
      end
    end
  end

  describe "#ready_to_run?" do
    let(:problem_tracker) { described_class.new(next_run_at:) }

    context "when the next run timestamp is not set" do
      let(:next_run_at) { nil }

      it { expect(problem_tracker).to be_ready_to_run }
    end

    context "when the next run timestamp is in the past" do
      let(:next_run_at) { 5.minutes.ago }

      it { expect(problem_tracker).to be_ready_to_run }
    end

    context "when the next run timestamp is in the future" do
      let(:next_run_at) { 5.minutes.from_now }

      it { expect(problem_tracker).not_to be_ready_to_run }
    end
  end

  describe "#failing?" do
    before { freeze_time }

    let(:problem_tracker) { described_class.new(last_problem_at:, last_run_at:, last_success_at:) }

    context "when the last run passed" do
      let(:last_run_at) { 1.minute.ago }
      let(:last_success_at) { 1.minute.ago }
      let(:last_problem_at) { 11.minutes.ago }

      it { expect(problem_tracker).not_to be_failing }
    end

    context "when the last run had a problem" do
      let(:last_run_at) { 1.minute.ago }
      let(:last_success_at) { 11.minutes.ago }
      let(:last_problem_at) { 1.minute.ago }

      it { expect(problem_tracker).to be_failing }
    end
  end

  describe "#passing?" do
    before { freeze_time }

    let(:problem_tracker) { described_class.new(last_problem_at:, last_run_at:, last_success_at:) }

    context "when the last run passed" do
      let(:last_run_at) { 1.minute.ago }
      let(:last_success_at) { 1.minute.ago }
      let(:last_problem_at) { 11.minutes.ago }

      it { expect(problem_tracker).to be_passing }
    end

    context "when the last run had a problem" do
      let(:last_run_at) { 1.minute.ago }
      let(:last_success_at) { 11.minutes.ago }
      let(:last_problem_at) { 1.minute.ago }

      it { expect(problem_tracker).not_to be_passing }
    end
  end

  describe "#problem!" do
    let(:problem_tracker) do
      Fabricate(
        :problem_check_tracker,
        identifier: "twitter_login",
        target: "foo",
        **original_attributes,
      )
    end

    let(:original_attributes) do
      {
        blips:,
        last_problem_at: 1.week.ago,
        last_success_at: 24.hours.ago,
        last_run_at: 24.hours.ago,
        next_run_at: nil,
      }
    end

    let(:blips) { 0 }
    let(:updated_attributes) { { blips: 1 } }

    it do
      freeze_time

      expect { problem_tracker.problem!(next_run_at: 24.hours.from_now) }.to change {
        problem_tracker.attributes
      }.to(hash_including(updated_attributes))
    end

    context "when the maximum number of blips have been surpassed" do
      let(:blips) { 1 }

      it "sounds the alarm" do
        expect { problem_tracker.problem!(next_run_at: 24.hours.from_now) }.to change {
          AdminNotice.problem.count
        }.by(1)
      end
    end

    context "when there's an alarm sounding for multi-target trackers" do
      let(:blips) { 1 }

      before do
        Fabricate(
          :admin_notice,
          subject: "problem",
          identifier: "twitter_login",
          details: {
            target: target,
          },
        )
      end

      context "when the alarm is for a different target" do
        let(:target) { "bar" }

        it "sounds the alarm" do
          expect { problem_tracker.problem!(next_run_at: 24.hours.from_now) }.to change {
            AdminNotice.problem.count
          }.by(1)
        end
      end

      context "when the alarm is for a the same target" do
        let(:target) { "foo" }

        it "does not duplicate the alarm" do
          expect { problem_tracker.problem!(next_run_at: 24.hours.from_now) }.not_to change {
            AdminNotice.problem.count
          }
        end
      end
    end

    context "when there are still blips to go" do
      let(:blips) { 0 }

      before { ProblemCheck::TwitterLogin.stubs(:max_blips).returns(1) }

      it "does not sound the alarm" do
        expect { problem_tracker.problem!(next_run_at: 24.hours.from_now) }.not_to change {
          AdminNotice.problem.count
        }
      end
    end
  end

  describe "#no_problem!" do
    let(:problem_tracker) do
      Fabricate(:problem_check_tracker, identifier: "twitter_login", **original_attributes)
    end

    let(:original_attributes) do
      {
        blips: 0,
        last_problem_at: 1.week.ago,
        last_success_at: Time.current,
        last_run_at: 24.hours.ago,
        next_run_at: nil,
      }
    end

    let(:updated_attributes) { { blips: 0 } }

    it do
      freeze_time

      expect { problem_tracker.no_problem!(next_run_at: 24.hours.from_now) }.to change {
        problem_tracker.attributes
      }.to(hash_including(updated_attributes))
    end

    context "when there's an alarm sounding" do
      before { problem_tracker.problem! }

      it "silences the alarm" do
        expect { problem_tracker.no_problem!(next_run_at: 24.hours.from_now) }.to change {
          AdminNotice.problem.count
        }.by(-1)
      end
    end
  end

  describe "#reset" do
    let(:problem_tracker) do
      Fabricate(:problem_check_tracker, identifier: "twitter_login", **original_attributes)
    end

    let(:original_attributes) do
      {
        blips: 0,
        last_problem_at: 1.week.ago,
        last_success_at: Time.current,
        last_run_at: 24.hours.ago,
        next_run_at: nil,
      }
    end

    let(:updated_attributes) { { blips: 0 } }

    it do
      freeze_time

      expect { problem_tracker.reset(next_run_at: 24.hours.from_now) }.to change {
        problem_tracker.attributes
      }.to(hash_including(updated_attributes))
    end
  end
end
