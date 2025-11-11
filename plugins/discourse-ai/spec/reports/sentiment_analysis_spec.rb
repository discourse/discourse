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
end
