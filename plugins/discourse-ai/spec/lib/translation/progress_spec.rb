# frozen_string_literal: true

describe DiscourseAi::Translation::Progress do
  before do
    Discourse.cache.clear
    SiteSetting.content_localization_supported_locales = "en|fr"
    SiteSetting.ai_translation_backfill_max_age_days = 30
    SiteSetting.ai_translation_category_scope = "public"

    allow(DiscourseAi::Translation::PostCandidates).to receive(:progress_summary).and_return(
      {
        target_type: "post",
        total_count: 10,
        translated_count: 4,
        needs_language_detection_count: 2,
      },
    )
    allow(DiscourseAi::Translation::TopicCandidates).to receive(:progress_summary).and_return(
      {
        target_type: "topic",
        total_count: 8,
        translated_count: 3,
        needs_language_detection_count: 1,
      },
    )
    allow(DiscourseAi::Translation::CategoryCandidates).to receive(:progress_summary).and_return(
      {
        target_type: "category",
        total_count: 5,
        translated_count: 5,
        needs_language_detection_count: 0,
      },
    )
    allow(DiscourseAi::Translation::TagCandidates).to receive(:progress_summary).and_return(
      {
        target_type: "tag",
        total_count: 7,
        translated_count: 2,
        needs_language_detection_count: 1,
      },
    )
  end

  it "caches all target summaries and their timestamp together for two hours" do
    cached_at = Time.zone.parse("2026-07-23 09:00:00 UTC")
    cache = Discourse.cache
    allow(cache).to receive(:fetch).and_call_original

    first_result = freeze_time(cached_at) { described_class.fetch }
    second_result = freeze_time(cached_at + 1.hour) { described_class.fetch }

    expect(second_result).to eq(first_result)
    expect(second_result[:cached_at]).to eq(cached_at.utc.iso8601)
    expect(second_result[:targets].map { |target| target[:target_type] }).to eq(
      %w[post topic category tag],
    )
    expect(cache).to have_received(:fetch).with(
      a_string_starting_with("discourse-ai:translation-progress-overview:v1:"),
      expires_in: 2.hours,
    ).twice
    expect(DiscourseAi::Translation::PostCandidates).to have_received(:progress_summary).once
    expect(DiscourseAi::Translation::TopicCandidates).to have_received(:progress_summary).once
    expect(DiscourseAi::Translation::CategoryCandidates).to have_received(:progress_summary).once
    expect(DiscourseAi::Translation::TagCandidates).to have_received(:progress_summary).once
    expect(described_class::CACHE_TTL).to eq(2.hours)
  end

  it "uses relevant site settings in the cache key" do
    described_class.fetch

    SiteSetting.content_localization_supported_locales = "en|de"
    described_class.fetch

    expect(DiscourseAi::Translation::PostCandidates).to have_received(:progress_summary).twice
    expect(DiscourseAi::Translation::TopicCandidates).to have_received(:progress_summary).twice
    expect(DiscourseAi::Translation::CategoryCandidates).to have_received(:progress_summary).twice
    expect(DiscourseAi::Translation::TagCandidates).to have_received(:progress_summary).twice
  end

  it "uses the configured category scope in the cache key" do
    category = Fabricate(:category)
    described_class.fetch

    SiteSetting.ai_translation_category_scope = "include_strict"
    SiteSetting.ai_translation_categories = category.id.to_s
    described_class.fetch

    expect(DiscourseAi::Translation::PostCandidates).to have_received(:progress_summary).twice
    expect(DiscourseAi::Translation::TopicCandidates).to have_received(:progress_summary).twice
    expect(DiscourseAi::Translation::CategoryCandidates).to have_received(:progress_summary).twice
    expect(DiscourseAi::Translation::TagCandidates).to have_received(:progress_summary).twice
  end
end
