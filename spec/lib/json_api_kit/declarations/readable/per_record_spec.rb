# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Readable::PerRecord do
  subject(:readable) { described_class.new(rule) }

  fab!(:topic)

  let(:guardian) { Guardian.new }
  let(:rule) { ->(_user, _record) { true } }

  describe "#per_record?" do
    it { is_expected.to be_per_record }
  end

  describe "#readable_by?" do
    context "when the rule refuses the record" do
      let(:rule) { ->(_user, _record) { false } }

      it "allows the user" do
        expect(readable).to be_readable_by(guardian)
      end
    end
  end

  describe "#readable_for?" do
    context "when the rule allows the record" do
      it "allows the record" do
        expect(readable).to be_readable_for(guardian, topic)
      end
    end

    context "when the rule refuses the record" do
      let(:rule) { ->(_user, _record) { false } }

      it "refuses the record" do
        expect(readable).not_to be_readable_for(guardian, topic)
      end
    end
  end
end
