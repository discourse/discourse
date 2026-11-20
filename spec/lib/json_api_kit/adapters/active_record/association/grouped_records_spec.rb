# frozen_string_literal: true

RSpec.describe JsonApiKit::Adapters::ActiveRecord::Association::GroupedRecords do
  let(:groups) { described_class.new(20 => first_group, 10 => last_group) }
  let(:first_group) { %i[third first] }
  let(:last_group) { [:second] }

  describe "#for" do
    subject(:records) { groups.for(key) }

    let(:key) { 20 }

    it "returns the matching group" do
      expect(records).to eq(first_group)
    end

    it "returns an independent array" do
      expect(records).not_to equal(first_group)
    end

    context "when the key has no loaded records" do
      let(:key) { 30 }

      it { is_expected.to be_empty }
    end
  end

  describe "#for_keys" do
    subject(:records) { groups.for_keys(keys) }

    let(:keys) { [10, 20] }

    it "preserves the loaded record order" do
      expect(records).to eq(%i[third first second])
    end

    context "when some keys have no loaded records" do
      let(:keys) { [30, *super(), 40] }

      it "returns only the loaded records" do
        expect(records).to eq(%i[third first second])
      end
    end
  end
end
