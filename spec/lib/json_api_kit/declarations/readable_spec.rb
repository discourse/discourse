# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Readable do
  describe ".for" do
    subject(:readable) { described_class.for(rule) }

    context "when no rule is declared" do
      let(:rule) { described_class::ALWAYS }

      it { is_expected.to be_a(described_class::PerUser) }
    end

    context "when the rule only looks at the user" do
      let(:rule) { ->(_user) { true } }

      it { is_expected.to be_a(described_class::PerUser) }
    end

    context "when the rule looks both at the user and the record" do
      let(:rule) { ->(_user, _record) { true } }

      it { is_expected.to be_a(described_class::PerRecord) }
    end
  end
end
