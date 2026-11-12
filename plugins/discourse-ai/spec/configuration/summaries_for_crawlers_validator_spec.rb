# frozen_string_literal: true

describe DiscourseAi::Configuration::SummariesForCrawlersValidator do
  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
  end

  it "rejects publishing summaries to crawlers while the summary backfill is off" do
    SiteSetting.ai_summary_backfill_maximum_topics_per_hour = 0

    expect { SiteSetting.ai_summaries_for_crawlers = true }.to raise_error(
      Discourse::InvalidParameters,
      /#{Regexp.escape(I18n.t("discourse_ai.summarization.configuration.backfill_required"))}/,
    )
  end

  it "allows publishing summaries to crawlers when the summary backfill is on" do
    SiteSetting.ai_summary_backfill_maximum_topics_per_hour = 10

    SiteSetting.ai_summaries_for_crawlers = true

    expect(SiteSetting.ai_summaries_for_crawlers).to eq(true)
  end

  it "allows turning off crawler summaries after the backfill is turned off" do
    SiteSetting.ai_summary_backfill_maximum_topics_per_hour = 10
    SiteSetting.ai_summaries_for_crawlers = true
    SiteSetting.ai_summary_backfill_maximum_topics_per_hour = 0

    SiteSetting.ai_summaries_for_crawlers = false

    expect(SiteSetting.ai_summaries_for_crawlers).to eq(false)
  end
end
