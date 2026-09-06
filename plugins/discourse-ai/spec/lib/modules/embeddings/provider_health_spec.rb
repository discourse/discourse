# frozen_string_literal: true

RSpec.describe DiscourseAi::Embeddings::ProviderHealth do
  fab!(:definition, :open_ai_embedding_def)

  after { described_class.clear!(definition) }

  def error(category)
    DiscourseAi::Inference::EmbeddingInferenceError.new(
      provider: definition.provider,
      category: category,
      http_status: 429,
      provider_error_code: category,
    )
  end

  def pause_key
    "discourse_ai:embedding_provider_paused:#{definition.id}"
  end

  def pause_ttl
    Discourse.redis.ttl(pause_key)
  end

  it "pauses once for terminal failures and skips later provider calls" do
    allow(Rails.logger).to receive(:warn)

    expect {
      described_class.request!(definition) { raise error(:quota_exhausted) }
    }.to raise_error(DiscourseAi::Inference::EmbeddingInferenceError)

    expect {
      described_class.request!(definition) { raise error(:quota_exhausted) }
    }.to raise_error(DiscourseAi::Embeddings::ProviderPausedError)

    contacted = false
    expect { described_class.request!(definition) { contacted = true } }.to raise_error(
      DiscourseAi::Embeddings::ProviderPausedError,
    )
    expect(contacted).to eq(false)
    expect(Rails.logger).to have_received(:warn).once
  end

  it "progressively increases pauses for consecutive terminal failures" do
    expected_backoffs = [30.seconds, 3.minutes, 20.minutes, 1.hour, 6.hours, 6.hours]

    expected_backoffs.each do |expected_backoff|
      expect {
        described_class.request!(definition) { raise error(:authentication_failed) }
      }.to raise_error(DiscourseAi::Inference::EmbeddingInferenceError)
      expect(pause_ttl).to be_between(expected_backoff.to_i - 1, expected_backoff.to_i)

      Discourse.redis.del(pause_key)
    end
  end

  it "resets the backoff after a successful provider request" do
    expect {
      described_class.request!(definition) { raise error(:quota_exhausted) }
    }.to raise_error(DiscourseAi::Inference::EmbeddingInferenceError)
    Discourse.redis.del(pause_key)

    expect(described_class.request!(definition) { :embedding }).to eq(:embedding)
    expect {
      described_class.request!(definition) { raise error(:quota_exhausted) }
    }.to raise_error(DiscourseAi::Inference::EmbeddingInferenceError)

    expect(pause_ttl).to be_between(29, 30)
  end

  it "does not pause temporary rate limits" do
    expect { described_class.request!(definition) { raise error(:rate_limited) } }.to raise_error(
      DiscourseAi::Inference::EmbeddingInferenceError,
    )

    expect(described_class).not_to be_paused(definition)
  end

  it "does not share health state with unsaved definitions" do
    unsaved =
      EmbeddingDefinition.new(definition.attributes.except("id", "created_at", "updated_at"))

    expect { described_class.request!(unsaved) { raise error(:quota_exhausted) } }.to raise_error(
      DiscourseAi::Inference::EmbeddingInferenceError,
    )
    expect(described_class).not_to be_paused(unsaved)
  end

  it "clears the pause and backoff after the definition changes" do
    expect {
      described_class.request!(definition) { raise error(:authentication_failed) }
    }.to raise_error(DiscourseAi::Inference::EmbeddingInferenceError)

    definition.clear_provider_pause
    expect(described_class).not_to be_paused(definition)

    expect {
      described_class.request!(definition) { raise error(:authentication_failed) }
    }.to raise_error(DiscourseAi::Inference::EmbeddingInferenceError)
    expect(pause_ttl).to be_between(29, 30)
  end
end
