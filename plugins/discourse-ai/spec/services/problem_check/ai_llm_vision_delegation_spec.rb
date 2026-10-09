# frozen_string_literal: true

RSpec.describe ProblemCheck::AiLlmVisionDelegation do
  subject(:check) { described_class.new(delegated_model.id) }

  fab!(:native_model) { Fabricate(:llm_model, vision_enabled: true) }
  fab!(:delegated_model) { Fabricate(:llm_model, vision_llm_model: native_model) }

  before { enable_current_plugin }

  it "returns no problem for a valid native target" do
    expect(check).to be_chill_about_it
  end

  it "reports a missing or demoted target" do
    delegated_model.update_column(:vision_llm_model_id, 99_999_999)

    result = check.call
    expect(result).to have_attributes(priority: "high", target: delegated_model.id)
    expect(result.message).to include("no longer exists")

    delegated_model.update_column(:vision_llm_model_id, native_model.id)
    native_model.update_column(:vision_enabled, false)

    expect(check.call.message).to include("does not support native image input")
  end
end
