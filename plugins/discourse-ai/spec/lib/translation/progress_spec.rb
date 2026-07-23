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

    [
      DiscourseAi::Translation::PostCandidates,
      DiscourseAi::Translation::TopicCandidates,
      DiscourseAi::Translation::CategoryCandidates,
      DiscourseAi::Translation::TagCandidates,
    ].each do |candidate_class|
      target_type = candidate_class.name.demodulize.delete_suffix("Candidates").underscore
      denominator_key = target_type == "tag" ? :total_count : :eligible_count
      allow(candidate_class).to receive(:progress_details).and_return(
        {
          target_type:,
          locales: [
            { :locale => "en", :translated_count => 3, :pending_count => 2, denominator_key => 5 },
          ],
        },
      )
    end
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

  describe ".fetch_detail" do
    it "caches each target independently for two hours" do
      cached_at = Time.zone.parse("2026-07-23 09:00:00 UTC")
      cache = Discourse.cache
      allow(cache).to receive(:fetch).and_call_original
      allow(cache).to receive(:read).and_call_original

      first_post = freeze_time(cached_at) { described_class.fetch_detail("post") }
      second_post = freeze_time(cached_at + 1.hour) { described_class.fetch_detail("post") }
      topic = freeze_time(cached_at + 1.hour) { described_class.fetch_detail("topic") }

      expect(second_post).to eq(first_post)
      expect(first_post[:cached_at]).to eq(cached_at.utc.iso8601)
      expect(topic[:cached_at]).to eq((cached_at + 1.hour).utc.iso8601)
      expect(cache).to have_received(:fetch).with(
        a_string_starting_with("discourse-ai:translation-progress-detail:v1:post:"),
        expires_in: 2.hours,
      ).once
      expect(cache).to have_received(:fetch).with(
        a_string_starting_with("discourse-ai:translation-progress-detail:v1:topic:"),
        expires_in: 2.hours,
      ).once
      expect(cache).to have_received(:read).with(
        a_string_starting_with("discourse-ai:translation-progress-detail:v1:post:"),
      ).twice
      expect(cache).to have_received(:read).with(
        a_string_starting_with("discourse-ai:translation-progress-detail:v1:topic:"),
      ).once
      expect(DiscourseAi::Translation::PostCandidates).to have_received(:progress_details).once
      expect(DiscourseAi::Translation::TopicCandidates).to have_received(:progress_details).once
      expect(DiscourseAi::Translation::CategoryCandidates).not_to have_received(:progress_details)
      expect(DiscourseAi::Translation::TagCandidates).not_to have_received(:progress_details)
    end

    it "runs one query when concurrent requests miss the same target cache" do
      query_started = Queue.new
      release_queries = Queue.new
      call_count = 0

      allow(DiscourseAi::Translation::PostCandidates).to receive(:progress_details) do
        call_count += 1
        query_started << true
        release_queries.pop
        { target_type: "post", locales: [] }
      end

      first_request = Thread.new { described_class.fetch_detail("post") }
      query_started.pop
      second_request = Thread.new { described_class.fetch_detail("post") }

      sleep 0.05
      2.times { release_queries << true }
      results = [first_request.value, second_request.value]

      expect(call_count).to eq(1)
      expect(results.uniq.length).to eq(1)
    end

    it "rejects unsupported target types" do
      expect { described_class.fetch_detail("user") }.to raise_error(ArgumentError)
    end
  end
end
