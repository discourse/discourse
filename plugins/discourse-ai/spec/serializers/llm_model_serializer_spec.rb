# frozen_string_literal: true

RSpec.describe LlmModelSerializer do
  fab!(:admin)

  before { enable_current_plugin }

  describe "#include_credit_allocation?" do
    let(:scope) { { llm_usage: {} } }

    context "when model is not seeded" do
      it "returns nil for credit allocation" do
        llm_model = Fabricate(:llm_model)
        serialized = described_class.new(llm_model, scope: scope, root: false)
        json = JSON.parse(serialized.to_json)

        expect(json["llm_credit_allocation"]).to be_nil
        expect(json["llm_feature_credit_costs"]).to eq([])
      end
    end

    context "when model is seeded but has no credit allocation" do
      it "returns nil for credit allocation" do
        llm_model = Fabricate(:llm_model, id: -100)
        serialized = described_class.new(llm_model, scope: scope, root: false)
        json = JSON.parse(serialized.to_json)

        expect(json["llm_credit_allocation"]).to be_nil
        expect(json["llm_feature_credit_costs"]).to eq([])
      end

      it "does not raise an error when serializing" do
        llm_model = Fabricate(:llm_model, id: -101)

        expect {
          described_class.new(llm_model, scope: scope, root: false).to_json
        }.not_to raise_error
      end
    end

    context "when model is seeded and has credit allocation" do
      it "includes credit allocation fields" do
        llm_model = Fabricate(:llm_model, id: -102)
        Fabricate(:llm_credit_allocation, llm_model: llm_model)

        serialized = described_class.new(llm_model, scope: scope, root: false)
        json = JSON.parse(serialized.to_json)

        expect(json).to have_key("llm_credit_allocation")
        expect(json).to have_key("llm_feature_credit_costs")
        expect(json["llm_credit_allocation"]).to be_present
      end
    end
  end
end
