# frozen_string_literal: true

RSpec.describe ProblemCheck do
  # rubocop:disable RSpec/BeforeAfterAll
  before(:all) do
    ScheduledCheck = Class.new(described_class) { self.perform_every = 30.minutes }
    UnscheduledCheck = Class.new(described_class)
  end

  after(:all) do
    Object.send(:remove_const, ScheduledCheck.name)
    Object.send(:remove_const, UnscheduledCheck.name)
  end
  # rubocop:enable RSpec/BeforeAfterAll

  let(:scheduled_check) { ScheduledCheck }
  let(:unscheduled_check) { UnscheduledCheck }

  describe ".[]" do
    it { expect(described_class[:scheduled_check]).to eq(scheduled_check) }
    it { expect(described_class[:foo]).to eq(nil) }
  end

  describe ".identifier" do
    it { expect(scheduled_check.identifier).to eq(:scheduled_check) }
  end

  describe ".checks" do
    it { expect(described_class.checks).to include(scheduled_check, unscheduled_check) }
  end

  describe ".scheduled" do
    it { expect(described_class.scheduled).to include(scheduled_check) }
    it { expect(described_class.scheduled).not_to include(unscheduled_check) }
  end

  describe ".scheduled?" do
    it { expect(scheduled_check).to be_scheduled }
    it { expect(unscheduled_check).to_not be_scheduled }
  end
end
