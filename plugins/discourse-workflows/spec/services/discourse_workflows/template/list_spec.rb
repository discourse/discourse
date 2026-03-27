# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Template::List do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    let(:params) { {} }

    it { is_expected.to run_successfully }

    it "returns an array of templates" do
      expect(result[:templates]).to be_an(Array)
      expect(result[:templates]).not_to be_empty
    end

    it "returns templates with the expected attributes" do
      template = result[:templates].first
      expect(template).to have_key(:id)
      expect(template).to have_key(:name)
      expect(template).to have_key(:description)
      expect(template).to have_key(:node_types)
    end

    it "includes known templates from config/templates" do
      ids = result[:templates].map { |t| t[:id] }
      expect(ids).to include("auto-tag-topics")
    end
  end
end
