# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Template::Show do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:template_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    let(:params) { { template_id: } }
    let(:template_id) { "auto-tag-topics" }

    context "when contract is invalid" do
      let(:template_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when template is not found" do
      let(:template_id) { "nonexistent-template" }

      it { is_expected.to fail_to_find_a_model(:template) }
    end

    context "when template exists" do
      it { is_expected.to run_successfully }

      it "returns the parsed template data" do
        expect(result[:template]).to be_a(Hash)
        expect(result[:template]["name"]).to eq("Auto-tag new topics")
      end
    end
  end
end
