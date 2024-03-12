# frozen_string_literal: true

RSpec.describe ProblemCheck::TranslationOverrides do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Fabricate(:translation_override, status: status) }

    context "when there are outdated translation overrides" do
      let(:status) { "outdated" }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when there are translation overrides with invalid interpolation keys" do
      let(:status) { "invalid_interpolation_keys" }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when all translation overrides are fine" do
      let(:status) { "up_to_date" }

      it { expect(check.call).to be_empty }
    end
  end
end
