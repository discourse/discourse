# frozen_string_literal: true

RSpec.describe DuplicateTopicTitlesSiteSetting do
  it "exposes predicates on the setting value" do
    SiteSetting.duplicate_topic_titles = "allowed_across_categories"
    expect(SiteSetting.duplicate_topic_titles.allowed_across_categories?).to eq(true)
    expect(SiteSetting.duplicate_topic_titles.allowed?).to eq(false)
    expect(SiteSetting.duplicate_topic_titles.disallowed?).to eq(false)
    expect(SiteSetting.duplicate_topic_titles).to eq("allowed_across_categories")
  end

  it "wraps the default value" do
    expect(SiteSetting.duplicate_topic_titles.disallowed?).to eq(true)
  end
end
