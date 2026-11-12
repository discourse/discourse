# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::SetTopicSummary do
  subject(:tool) do
    described_class.new(
      parameters,
      bot_user: Discourse.system_user,
      llm: DiscourseAi::Completions::Llm.proxy(llm_model),
    )
  end

  let(:parameters) { { summary: "  日本語の要約です。  " } }
  let(:llm_model) { assign_fake_provider_to(:ai_default_llm_model) }

  before { enable_current_plugin }

  it "captures a valid summary and ends the tool chain" do
    expect(tool.invoke).to eq(status: "success")
    expect(tool.custom_raw).to eq("日本語の要約です。")
    expect(tool.chain_next_response?).to eq(false)
  end

  it "rejects a blank summary and allows the model to retry" do
    parameters[:summary] = "  "

    expect(tool.invoke).to eq(status: "error", error: "The topic summary must not be blank")
    expect(tool.custom_raw).to be_nil
    expect(tool.chain_next_response?).to eq(true)
  end

  it "rejects an over-length summary and allows the model to retry" do
    parameters[:summary] = "a" * (described_class::MAX_SUMMARY_LENGTH + 1)

    expect(tool.invoke).to eq(status: "error", error: "The topic summary is too long")
    expect(tool.custom_raw).to be_nil
    expect(tool.chain_next_response?).to eq(true)
  end
end
