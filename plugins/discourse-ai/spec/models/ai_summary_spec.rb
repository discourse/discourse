# frozen_string_literal: true

RSpec.describe AiSummary do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:, post_number: 1) }

  let(:llm_model) { assign_fake_provider_to(:ai_default_llm_model) }

  before { enable_current_plugin }

  it "persists unsupported content languages using a supported cooking locale" do
    SiteSetting.ai_summaries_for_crawlers = false
    strategy = DiscourseAi::Summarization::Strategies::TopicSummary.new(topic, locale: "hi")
    summary =
      described_class.store!(strategy, llm_model, "**सारांश**", strategy.targets_data, human: true)

    expect(summary.locale).to eq("hi")
    expect(summary.summarized_cooked).to include("<strong>सारांश</strong>")

    summary.update!(summarized_text: "Updated **सारांश**")
    expect(summary.reload.summarized_cooked).to include("Updated <strong>सारांश</strong>")

    summary.update_columns(summarized_cooked: nil)
    timestamp = summary.updated_at
    summary.cook_missing!
    expect(summary.reload.summarized_cooked).to include("Updated <strong>सारांश</strong>")
    expect(summary.locale).to eq("hi")
    expect(summary.updated_at).to eq_time(timestamp)
  end

  it "stores and updates gist text without cooking HTML" do
    strategy = DiscourseAi::Summarization::Strategies::HotTopicGists.new(topic, locale: "en")
    summary =
      described_class.store!(strategy, llm_model, "**Gist**", strategy.targets_data, human: true)
    expect(summary.summarized_cooked).to be_nil

    summary =
      described_class.store!(
        strategy,
        llm_model,
        "**Revised gist**",
        strategy.targets_data,
        human: true,
      )
    expect(summary.summarized_text).to eq("**Revised gist**")
    expect(summary.summarized_cooked).to be_nil

    summary.update!(summarized_text: "**Edited gist**")
    summary.cook_missing!
    expect(summary.reload.summarized_cooked).to be_nil

    summary.update!(summary_type: :complete)
    expect(summary.reload.summarized_cooked).to include("<strong>Edited gist</strong>")
    summary.update!(summary_type: :gist)
    expect(summary.reload.summarized_cooked).to be_nil
  end

  it "stores sanitized cooked content and replaces it when regenerating a summary" do
    strategy = DiscourseAi::Summarization::Strategies::TopicSummary.new(topic, locale: "en")
    summary =
      described_class.store!(
        strategy,
        llm_model,
        "**Overview** <script>alert(1)</script>",
        strategy.targets_data,
        human: true,
      )

    expect(summary.summarized_cooked).to include("<strong>Overview</strong>")
    expect(summary.summarized_cooked).not_to include("<script>")

    regenerated =
      described_class.store!(
        strategy,
        llm_model,
        "A revised **summary**",
        strategy.targets_data,
        human: true,
      )

    expect(regenerated.id).to eq(summary.id)
    expect(regenerated.summarized_cooked).to include("A revised <strong>summary</strong>")
    expect(regenerated.summarized_cooked).not_to include("Overview")
  end

  it "recooks changed text on ordinary saves" do
    summary = Fabricate(:ai_summary, target: topic)
    summary.update!(summarized_text: "Updated **text**")

    expect(summary.reload.summarized_cooked).to include("Updated <strong>text</strong>")
  end

  it "cooks missing HTML without changing the summary freshness timestamp" do
    summary = Fabricate(:ai_summary, target: topic, summarized_text: "**Original**")
    summary.update_columns(summarized_cooked: nil)
    updated_at = summary.updated_at

    summary.cook_missing!

    expect(summary.reload.summarized_cooked).to include("<strong>Original</strong>")
    expect(summary.updated_at).to eq_time(updated_at)
  end

  it "does not overwrite a regenerated summary when cooking an older snapshot" do
    summary = Fabricate(:ai_summary, target: topic, summarized_text: "Old summary")
    summary.update_columns(summarized_cooked: nil)
    snapshot = described_class.find(summary.id)
    summary.update!(summarized_text: "New **summary**")

    snapshot.cook_missing!

    expect(summary.reload.summarized_cooked).to include("New <strong>summary</strong>")
    expect(summary.summarized_text).to eq("New **summary**")
  end

  it "leaves existing cooked HTML alone" do
    summary = Fabricate(:ai_summary, target: topic)
    summary.update_columns(summarized_cooked: "<p>Previously cooked</p>")

    summary.cook_missing!

    expect(summary.reload.summarized_cooked).to eq("<p>Previously cooked</p>")
  end

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
