# frozen_string_literal: true

RSpec.describe DiscourseAi::Sentiment::SentimentAnalysisReport do
  fab!(:admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, user: admin, topic: topic) }
  fab!(:post_2) { Fabricate(:post, user: admin, topic: topic) }
  fab!(:classification_result) { Fabricate(:classification_result, target: post) }

  before do
    enable_current_plugin
    SiteSetting.ai_sentiment_enabled = true
  end

  it "contains the correct filters" do
    report = Report.find("sentiment_analysis")
    expect(report.available_filters).to include("group_by", "sort_by", "category", "tag")
  end

  it "contains the correct labels" do
    report = Report.find("sentiment_analysis")
    expect(report.labels).to eq(%w[Positive Neutral Negative])
  end

  it "produces data that can be cached for the admin dashboard" do
    Fabricate(:sentiment_classification, target: post)

    report = Report.find("sentiment_analysis")

    expect(report.data).to be_present
    expect(report.data).to all(be_a(Hash))
    expect { Report.cache(report) }.not_to raise_error
  end

  it "selects decision results in grouped and overall reports without counting dedicated results" do
    SiteSetting.ai_sentiment_sentiment_classification_strategy = "decision_model"
    Fabricate(
      :sentiment_classification,
      target: post,
      classification: {
        negative: 0.8,
        neutral: 0.1,
        positive: 0.1,
      },
    )
    Fabricate(
      :sentiment_classification,
      target: post_2,
      classification: {
        negative: 0.8,
        neutral: 0.1,
        positive: 0.1,
      },
    )
    Fabricate(
      :sentiment_classification,
      target: post,
      model_used: "discourse-ai/sentiment-decision",
      classification: {
        negative: 0.15,
        neutral: 0.2,
        positive: 0.65,
      },
    )

    report = Report.find("sentiment_analysis")

    expect(report.data).to contain_exactly(
      {
        category_id: category.id,
        category_name: category.name,
        positive_count: 1,
        negative_count: 0,
        total_count: 1,
      },
    )
    expect(Report.find("overall_sentiment").data.sole[:data].map { |point| point[:y] }).to eq([1])
  end

  it "uses the emotion decision key without changing emotion report thresholds" do
    SiteSetting.ai_sentiment_emotion_classification_strategy = "decision_model"
    Fabricate(
      :sentiment_classification,
      target: post_2,
      model_used: DiscourseAi::Sentiment::Constants::EMOTION_MODEL,
      classification: {
        joy: 0.9,
      },
    )
    Fabricate(
      :sentiment_classification,
      target: post,
      model_used: "discourse-ai/emotion-decision",
      classification: {
        joy: 0.15,
        approval: 0.85,
      },
    )

    expect(Report.find("emotion_joy").data.map { |point| point[:y] }).to eq([1])
  end
end
