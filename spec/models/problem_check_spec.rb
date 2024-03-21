# frozen_string_literal: true

RSpec.describe ProblemCheck do
  # rubocop:disable RSpec/BeforeAfterAll
  before(:all) do
    ScheduledCheck = Class.new(described_class) { self.perform_every = 30.minutes }
    RealtimeCheck = Class.new(described_class)
  end

  after(:all) do
    Object.send(:remove_const, ScheduledCheck.name)
    Object.send(:remove_const, RealtimeCheck.name)
  end
  # rubocop:enable RSpec/BeforeAfterAll

  let(:scheduled_check) { ScheduledCheck }
  let(:realtime_check) { RealtimeCheck }

  describe ".[]" do
    it { expect(described_class[:scheduled_check]).to eq(scheduled_check) }
    it { expect(described_class[:foo]).to eq(nil) }
  end

  describe ".identifier" do
    it { expect(scheduled_check.identifier).to eq(:scheduled_check) }
  end

  describe ".checks" do
    it { expect(described_class.checks).to include(scheduled_check, realtime_check) }
  end

  describe ".scheduled" do
    it { expect(described_class.scheduled).to include(scheduled_check) }
    it { expect(described_class.scheduled).not_to include(realtime_check) }
  end

  describe ".realtime" do
    it { expect(described_class.realtime).to include(realtime_check) }
    it { expect(described_class.realtime).not_to include(scheduled_check) }
  end

  describe ".scheduled?" do
    it { expect(scheduled_check).to be_scheduled }
    it { expect(realtime_check).to_not be_scheduled }
  end

  describe ".realtime?" do
    it { expect(realtime_check).to be_realtime }
    it { expect(scheduled_check).to_not be_realtime }
  end
end
