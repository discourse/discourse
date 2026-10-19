# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::EmotionFilterOrder do
  let(:plugin) { Plugin::Instance.new }
  let(:guardian) { Guardian.new }

  before do
    enable_current_plugin
    described_class.register!(plugin)
  end

  it "registers emotion filters" do
    emotions = %w[
      disappointment
      sadness
      annoyance
      neutral
      disapproval
      realization
      nervousness
      approval
      joy
      anger
      embarrassment
      caring
      remorse
      disgust
      grief
      confusion
      relief
      desire
      admiration
      optimism
      fear
      love
      excitement
      curiosity
      amusement
      surprise
      gratitude
      pride
    ]

    filters = DiscoursePluginRegistry.custom_filter_mappings.reduce(Hash.new, :merge)

    emotions.each { |emotion| expect(filters).to include("order:emotion_#{emotion}") }
  end

  it "filters topics by emotion" do
    emotion = "joy"
    scope = Topic.all
    order_direction = "desc"

    filter =
      DiscoursePluginRegistry
        .custom_filter_mappings
        .find { it.keys.include? "order:emotion_#{emotion}" }
        .values
        .first
    result = filter.call(scope, order_direction, guardian)

    expect(result.to_sql).to include("classification_results")
    expect(result.to_sql).to include(
      "classification_results.model_used = 'SamLowe/roberta-base-go_emotions'",
    )
    expect(result.to_sql).to include("ORDER BY topic_emotion.emotion_joy desc")
  end

  context "when emotion classification uses an agent" do
    before { SiteSetting.ai_sentiment_emotion_classification_strategy = "agent" }

    it "filters topics using the stable emotion agent model key" do
      emotion = "joy"
      filter =
        DiscoursePluginRegistry
          .custom_filter_mappings
          .find { it.keys.include? "order:emotion_#{emotion}" }
          .values
          .first
      result = filter.call(Topic.all, "desc", guardian)

      expect(result.to_sql).to include(
        "classification_results.model_used = '#{DiscourseAi::Sentiment::Constants::EMOTION_AGENT_MODEL}'",
      )
    end
  end

  context "with classified topics" do
    fab!(:post_1, :post)
    fab!(:post_2, :post)
    fab!(:post_3, :post)
    fab!(:classification_result_1) do
      Fabricate(
        :sentiment_classification,
        target: post_1,
        model_used: "SamLowe/roberta-base-go_emotions",
        classification: {
          love: 0.94,
        },
      )
    end
    fab!(:classification_result_2) do
      Fabricate(
        :sentiment_classification,
        target: post_2,
        model_used: "SamLowe/roberta-base-go_emotions",
        classification: {
          love: 0.84,
        },
      )
    end
    fab!(:classification_result_3) do
      Fabricate(
        :sentiment_classification,
        target: post_3,
        model_used: "SamLowe/roberta-base-go_emotions",
        classification: {
          love: 0.001,
          anger: 0.85,
        },
      )
    end

    it "filters classified topics for either sort direction and excludes low scores" do
      %w[order:emotion_love-asc order:emotion_love].each do |query|
        expect(
          TopicsFilter.new(guardian:).filter_from_query_string(query).pluck(:id),
        ).to contain_exactly(post_1.topic_id, post_2.topic_id)
      end
    end
  end
end
