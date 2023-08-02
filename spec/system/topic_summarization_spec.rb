# frozen_string_literal: true

RSpec.describe "Topic summarization", type: :system, js: true do
  fab!(:user) { Fabricate(:admin) }

  # has_summary to force topic map to be present.
  fab!(:topic) { Fabricate(:topic, has_summary: true) }
  fab!(:post_1) { Fabricate(:post, topic: topic) }
  fab!(:post_2) { Fabricate(:post, topic: topic) }

  let(:plugin) { Plugin::Instance.new }

  let(:expected_summary) { "This is a summary" }
  let(:summarization_result) { { summary: expected_summary, chunks: [] } }

  before do
    sign_in(user)
    strategy = DummyCustomSummarization.new(summarization_result)
    plugin.register_summarization_strategy(strategy)
    SiteSetting.summarization_strategy = strategy.model
  end

  it "returns a summary using the selected timeframe" do
    visit("/t/-/#{topic.id}")

    find(".topic-strategy-summarization").click

    summary = find(".summary-box .generated-summary p").text

    expect(summary).to eq(expected_summary)
  end
end
