# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::Readable::PerUser do
  subject(:readable) { described_class.new(rule) }

  fab!(:topic)

  let(:guardian) { Guardian.new }
  let(:rule) { ->(_user) { true } }

  describe "#per_record?" do
    it { is_expected.not_to be_per_record }
  end

  describe "#readable_by?" do
    context "when the rule allows the user" do
      it "allows the user" do
        expect(readable).to be_readable_by(guardian)
      end
    end

    context "when the rule refuses the user" do
      let(:rule) { ->(_user) { false } }

      it "refuses the user" do
        expect(readable).not_to be_readable_by(guardian)
      end
    end
  end

  describe "#readable_for?" do
    context "when the rule refuses the user" do
      let(:rule) { ->(_user) { false } }

      it "allows the record" do
        expect(readable).to be_readable_for(guardian, topic)
      end
    end
  end
end
