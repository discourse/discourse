# frozen_string_literal: true

RSpec.describe AiSummary do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:, post_number: 1) }

  let(:llm_model) { assign_fake_provider_to(:ai_default_llm_model) }

  before { enable_current_plugin }

  it "stores and independently upserts topic gists by locale" do
    english_strategy =
      DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic, locale: "en")
    japanese_strategy =
      DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic, locale: "ja")

    described_class.store!(
      english_strategy,
      llm_model,
      "English summary",
      english_strategy.targets_data,
      human: false,
    )
    described_class.store!(
      japanese_strategy,
      llm_model,
      "日本語の要約",
      japanese_strategy.targets_data,
      human: false,
    )
    described_class.store!(
      japanese_strategy,
      llm_model,
      "更新された要約",
      japanese_strategy.targets_data,
      human: false,
    )

    expect(
      described_class.gist.where(target: topic).pluck(:locale, :summarized_text),
    ).to contain_exactly(["en", "English summary"], %w[ja 更新された要約])
  end

  describe ".store! with a locale-agnostic unique index" do
    let(:connection) { ActiveRecord::Base.connection }
    let(:legacy_index_name) { AiSummary::LEGACY_UNIQUE_INDEX_NAME }
    let(:other_index_name) { "idx_ai_summaries_spec_nonlegacy" }

    after do
      connection.remove_index(:ai_summaries, name: legacy_index_name, if_exists: true)
      connection.remove_index(:ai_summaries, name: other_index_name, if_exists: true)
    end

    it "deletes the conflicting legacy row and stores the requested locale" do
      legacy_gist = Fabricate(:topic_ai_gist, target: topic, locale: "en")
      connection.add_index(
        :ai_summaries,
        %i[target_id target_type summary_type],
        unique: true,
        name: legacy_index_name,
      )
      strategy = DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic, locale: "ja")

      stored_gist =
        described_class.store!(strategy, llm_model, "日本語の要約", strategy.targets_data, human: false)

      expect(described_class.exists?(legacy_gist.id)).to eq(false)
      expect(stored_gist).to have_attributes(locale: "ja", summarized_text: "日本語の要約")
    end

    it "preserves the conflicting row and raises for a different unique index" do
      existing_gist = Fabricate(:topic_ai_gist, target: topic, locale: "en")
      connection.add_index(
        :ai_summaries,
        %i[target_id target_type summary_type],
        unique: true,
        name: other_index_name,
      )
      strategy = DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic, locale: "ja")

      expect do
        described_class.store!(strategy, llm_model, "日本語の要約", strategy.targets_data, human: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)

      expect(existing_gist.reload.summarized_text).to eq("gist")
    end
  end

  it "replaces an equivalent regional-locale gist" do
    topic.update!(locale: "pt_BR")
    old_gist = Fabricate(:topic_ai_gist, target: topic, locale: "pt")
    strategy = DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic, locale: "pt_BR")

    stored_gist =
      described_class.store!(
        strategy,
        llm_model,
        "Resumo atualizado",
        strategy.targets_data,
        human: false,
      )

    expect(stored_gist.locale).to eq("pt_BR")
    expect(described_class.exists?(old_gist.id)).to eq(false)
  end

  it "replaces an equivalent regional-locale complete summary" do
    topic.update!(locale: "pt_BR")
    old_summary = Fabricate(:ai_summary, target: topic, locale: "pt")
    strategy = DiscourseAi::Summarization::Strategies::TopicSummary.new(topic, locale: "pt_BR")

    stored_summary =
      described_class.store!(
        strategy,
        llm_model,
        "Resumo atualizado",
        strategy.targets_data,
        human: false,
      )

    expect(stored_summary.locale).to eq("pt_BR")
    expect(described_class.exists?(old_summary.id)).to eq(false)
  end
end
