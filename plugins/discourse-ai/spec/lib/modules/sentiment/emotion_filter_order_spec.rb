# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::EmotionFilterOrder do
  let(:plugin) { Plugin::Instance.new }
  let(:model_used) { "SamLowe/roberta-base-go_emotions" }
  let(:post_1) { Fabricate(:post) }
  let(:post_2) { Fabricate(:post) }
  let(:post_3) { Fabricate(:post) }
  let(:guardian) { Guardian.new }
  let(:classification_1) do
    {
      love: 0.9444406,
      admiration: 0.013724019,
      surprise: 0.010188869,
      excitement: 0.007888741,
      curiosity: 0.006301749,
      joy: 0.004060776,
      confusion: 0.0028238264,
      approval: 0.0018160914,
      realization: 0.001174849,
      neutral: 0.0008561869,
      amusement: 0.00075853954,
      disapproval: 0.0006987994,
      disappointment: 0.0006166883,
      anger: 0.0006000542,
      annoyance: 0.0005615011,
      desire: 0.00046368592,
      fear: 0.00045117878,
      sadness: 0.00041727215,
      gratitude: 0.00041727215,
      optimism: 0.00037112957,
      disgust: 0.00035552034,
      nervousness: 0.00022954118,
      embarrassment: 0.0002049572,
      caring: 0.00017737568,
      remorse: 0.00011407586,
      grief: 0.0001006716,
      pride: 0.00009681493,
      relief: 0.00008919009,
    }
  end
  let(:classification_2) do
    {
      love: 0.8444406,
      admiration: 0.113724019,
      surprise: 0.010188869,
      excitement: 0.007888741,
      curiosity: 0.006301749,
      joy: 0.004060776,
      confusion: 0.0028238264,
      approval: 0.0018160914,
      realization: 0.001174849,
      neutral: 0.0008561869,
      amusement: 0.00075853954,
      disapproval: 0.0006987994,
      disappointment: 0.0006166883,
      anger: 0.0006000542,
      annoyance: 0.0005615011,
      desire: 0.00046368592,
      fear: 0.00045117878,
      sadness: 0.00041727215,
      gratitude: 0.00041727215,
      optimism: 0.00037112957,
      disgust: 0.00035552034,
      nervousness: 0.00022954118,
      embarrassment: 0.0002049572,
      caring: 0.00017737568,
      remorse: 0.00011407586,
      grief: 0.0001006716,
      pride: 0.00009681493,
      relief: 0.00008919009,
    }
  end
  let(:classification_3) do
    {
      anger: 0.8503682,
      annoyance: 0.08113059,
      disgust: 0.020593312,
      disapproval: 0.013718102,
      neutral: 0.0074148285,
      disappointment: 0.005785964,
      sadness: 0.0028253668,
      curiosity: 0.0028253668,
      confusion: 0.0023885092,
      surprise: 0.001524171,
      embarrassment: 0.0012784768,
      love: 0.001177788,
      admiration: 0.0010892758,
      realization: 0.001080799,
      approval: 0.00102328,
      fear: 0.00097261387,
      amusement: 0.0007724123,
      excitement: 0.00059921003,
      gratitude: 0.00055852515,
      joy: 0.00054986606,
      optimism: 0.00050458545,
      desire: 0.00046849172,
      caring: 0.00037205798,
      remorse: 0.00028415458,
      grief: 0.00025973833,
      nervousness: 0.00024305031,
      pride: 0.00011661681,
      relief: 0.00007470753,
    }
  end
  let!(:classification_result_1) do
    Fabricate(
      :sentiment_classification,
      target: post_1,
      model_used: model_used,
      classification: classification_1,
    )
  end
  let!(:classification_result_2) do
    Fabricate(
      :sentiment_classification,
      target: post_2,
      model_used: model_used,
      classification: classification_2,
    )
  end
  let!(:classification_result_3) do
    Fabricate(
      :sentiment_classification,
      target: post_3,
      model_used: model_used,
      classification: classification_3,
    )
  end

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
        .find { _1.keys.include? "order:emotion_#{emotion}" }
        .values
        .first
    result = filter.call(scope, order_direction, guardian)

    expect(result.to_sql).to include("classification_results")
    expect(result.to_sql).to include(
      "classification_results.model_used = 'SamLowe/roberta-base-go_emotions'",
    )
    expect(result.to_sql).to include("ORDER BY topic_emotion.emotion_joy desc")
  end

  it "sorts emotion in ascending order" do
    expect(
      TopicsFilter.new(guardian:).filter_from_query_string("order:emotion_love-asc").pluck(:id),
    ).to contain_exactly(post_2.topic.id, post_1.topic.id)
  end
  it "sorts emotion in default descending order" do
    expect(
      TopicsFilter.new(guardian:).filter_from_query_string("order:emotion_love").pluck(:id),
    ).to contain_exactly(post_1.topic.id, post_2.topic.id)
  end
end
