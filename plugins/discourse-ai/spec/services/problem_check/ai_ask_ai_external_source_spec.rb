# frozen_string_literal: true

RSpec.describe ProblemCheck::AiAskAiExternalSource do
  subject(:check) { described_class.new(ai_tool.id) }

  fab!(:ai_tool) { Fabricate(:ai_tool, name: "Help center") }

  before do
    enable_current_plugin
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_external_sources = ai_tool.id.to_s
  end

  def record(outcome, times)
    times.times { DiscourseAi::Discoveries::ExternalSource.record_outcome(ai_tool.id, outcome) }
  end

  describe "#call" do
    it "returns a problem when most recent searches skipped the source" do
      record(:timed_out, 3)
      record(:busy, 1)
      record(:succeeded, 2)

      expect(check).to have_a_problem.with_priority("high").with_target(ai_tool.id)
      expect(check.call.message).to include("Help center", "4 of its last 6 searches")
    end

    it "is chill when most searches reached the source" do
      record(:failed, 2)
      record(:succeeded, 4)

      expect(check).to be_chill_about_it
    end

    it "is chill until the source has been searched enough to judge" do
      record(:timed_out, described_class::MIN_SEARCHES - 1)

      expect(check).to be_chill_about_it
    end

    it "only counts searches within the lookback window" do
      freeze_time(described_class::LOOKBACK_HOURS.hours.ago - 1.hour) { record(:timed_out, 5) }

      expect(check).to be_chill_about_it
    end

    it "is chill when Ask AI is disabled" do
      record(:timed_out, 5)
      SiteSetting.ai_ask_ai_enabled = false

      expect(check).to be_chill_about_it
    end
  end
end
