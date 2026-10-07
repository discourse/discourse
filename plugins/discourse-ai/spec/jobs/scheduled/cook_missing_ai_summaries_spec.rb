# frozen_string_literal: true

describe Jobs::CookMissingAiSummaries do
  before { enable_current_plugin }

  it "reserves batch capacity for complete topic summaries rather than gists" do
    gists = Fabricate.times(2, :topic_ai_gist)
    summary = Fabricate(:ai_summary, summarized_text: "**Complete summary**")
    AiSummary.where(id: gists.map(&:id) + [summary.id]).update_all(summarized_cooked: nil)

    stub_const(described_class, :BATCH_SIZE, 2) { described_class.new.execute({}) }

    expect(summary.reload.summarized_cooked).to include("<strong>Complete summary</strong>")
    expect(gists.map { |gist| gist.reload.summarized_cooked }).to eq([nil, nil])
  end

  it "cooks a bounded batch of missing HTML without LLM calls or timestamp changes" do
    summaries = Fabricate.times(3, :ai_summary, summarized_text: "**Stored summary**")
    AiSummary.where(id: summaries.map(&:id)).update_all(summarized_cooked: nil)
    timestamps = summaries.map(&:updated_at)
    SiteSetting.ai_summary_backfill_maximum_topics_per_hour = 0

    stub_const(described_class, :BATCH_SIZE, 2) do
      DiscourseAi::Completions::Llm.with_prepared_responses([]) { described_class.new.execute({}) }
    end

    expect(summaries.map { |summary| summary.reload.summarized_cooked.present? }).to eq(
      [true, true, false],
    )
    expect(summaries.first.summarized_cooked).to include("<strong>Stored summary</strong>")
    expect(summaries.map(&:updated_at)).to eq(timestamps)

    described_class.new.execute({})
    expect(summaries.last.reload.summarized_cooked).to include("<strong>Stored summary</strong>")
  end

  it "does not change existing cooked HTML" do
    summary = Fabricate(:ai_summary)
    summary.update_columns(summarized_cooked: "<p>Previously cooked</p>")

    described_class.new.execute({})

    expect(summary.reload.summarized_cooked).to eq("<p>Previously cooked</p>")
  end

  it "continues past a failing batch and retries missing records on a later pass" do
    summaries = Fabricate.times(3, :ai_summary, summarized_text: "**Stored summary**")
    AiSummary.where(id: summaries.map(&:id)).update_all(summarized_cooked: nil)
    PrettyText.stubs(:cook).raises(StandardError, "Renderer unavailable")

    stub_const(described_class, :BATCH_SIZE, 2) do
      described_class.new.execute({})
      PrettyText.unstub(:cook)
      described_class.new.execute({})

      expect(summaries.map { |summary| summary.reload.summarized_cooked.present? }).to eq(
        [false, false, true],
      )

      described_class.new.execute({})
      expect(summaries.map { |summary| summary.reload.summarized_cooked.present? }).to eq(
        [true, true, true],
      )
    end
  end

  it "leaves records alone when the plugin is disabled" do
    summary = Fabricate(:ai_summary)
    summary.update_columns(summarized_cooked: nil)
    SiteSetting.discourse_ai_enabled = false

    described_class.new.execute({})

    expect(summary.reload.summarized_cooked).to be_nil
  end
end
