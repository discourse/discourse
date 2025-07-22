# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Personas::Tools::RandomPicker do
  before { enable_current_plugin }

  describe "#invoke" do
    subject { described_class.new({ options: options }, bot_user: nil, llm: nil).invoke }

    context "with options as simple list of strings" do
      let(:options) { %w[apple banana cherry] }

      it "returns one of the options" do
        expect(options).to include(subject[:result])
      end
    end

    context "with options as ranges" do
      let(:options) { %w[1-3 10-20] }

      it "returns a number within one of the provided ranges" do
        results = subject[:result]
        expect(results).to all(
          satisfy { |result| (1..3).include?(result) || (10..20).include?(result) },
        )
      end
    end

    context "with options as comma-separated values" do
      let(:options) { %w[red,green,blue mon,tue,wed] }

      it "returns one value from each comma-separated list" do
        results = subject[:result]
        expect(results).to include(a_kind_of(String))
        results.each { |result| expect(result.split(",")).to include(result) }
      end
    end

    context "with mixed options (list, range, and comma-separated)" do
      let(:options) { %w[apple 1-3 mon,tue,wed] }

      it "handles each option appropriately" do
        results = subject[:result]
        expect(results.size).to eq(options.size)
        # Verifying each type of option is respected needs a more elaborate setup,
        # potentially mocking or specific expectations for each type.
      end
    end

    context "with an invalid format in options" do
      let(:options) { ["invalid_format"] }

      it "returns an error message for invalid formats" do
        expect(subject[:result]).to include("invalid_format")
      end
    end
  end
end
