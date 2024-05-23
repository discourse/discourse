# frozen_string_literal: true

RSpec.describe ProblemCheck do
  around do |example|
    ScheduledCheck = Class.new(described_class) { self.perform_every = 30.minutes }
    RealtimeCheck = Class.new(described_class)
    PluginCheck = Class.new(described_class)
    FailingCheck =
      Class.new(described_class) do
        def call
          problem
        end

        def translation_key
          "failing_check"
        end
      end
    PassingCheck =
      Class.new(described_class) do
        def call
          no_problem
        end

        def translation_key
          "passing_check"
        end
      end

    stub_const(
      described_class,
      "CORE_PROBLEM_CHECKS",
      [ScheduledCheck, RealtimeCheck, FailingCheck, PassingCheck],
      &example
    )

    Object.send(:remove_const, ScheduledCheck.name)
    Object.send(:remove_const, RealtimeCheck.name)
    Object.send(:remove_const, PluginCheck.name)
    Object.send(:remove_const, FailingCheck.name)
    Object.send(:remove_const, PassingCheck.name)
  end

  let(:scheduled_check) { ScheduledCheck }
  let(:realtime_check) { RealtimeCheck }
  let(:plugin_check) { PluginCheck }
  let(:failing_check) { FailingCheck }
  let(:passing_check) { PassingCheck }

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

  describe "plugin problem check registration" do
    before { DiscoursePluginRegistry.register_problem_check(PluginCheck, stub(enabled?: enabled)) }

    after { DiscoursePluginRegistry.reset! }

    context "when the plugin is enabled" do
      let(:enabled) { true }

      it { expect(described_class.checks).to include(plugin_check) }
    end

    context "when the plugin is disabled" do
      let(:enabled) { false }

      it { expect(described_class.checks).not_to include(plugin_check) }
    end
  end

  describe "#run" do
    context "when check is failing" do
      it { expect { failing_check.run }.to change { ProblemCheckTracker.failing.count }.by(1) }
    end

    context "when check is passing" do
      it { expect { passing_check.run }.to change { ProblemCheckTracker.passing.count }.by(1) }
    end
  end
end
