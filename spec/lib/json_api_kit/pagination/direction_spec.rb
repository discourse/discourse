# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Direction do
  subject(:direction) { described_class.for(declaration) }

  let(:declaration) { :asc }

  describe ".for" do
    context "when nothing sorts in that direction" do
      let(:declaration) { :sideways }

      it "refuses the direction" do
        expect { direction }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#to_sym" do
    context "when the declaration is asc" do
      it "returns asc" do
        expect(direction.to_sym).to eq(:asc)
      end
    end

    context "when the declaration is desc" do
      let(:declaration) { :desc }

      it "returns desc" do
        expect(direction.to_sym).to eq(:desc)
      end
    end
  end

  describe "#to_sql" do
    subject(:to_sql) { direction.to_sql }

    context "when the direction sorts ascending" do
      it "returns ASC" do
        expect(to_sql).to eq("ASC")
      end
    end

    context "when the direction sorts descending" do
      let(:declaration) { :desc }

      it "returns DESC" do
        expect(to_sql).to eq("DESC")
      end
    end
  end

  describe "#operator" do
    subject(:operator) { direction.operator }

    context "when the direction sorts ascending" do
      it "compares a later row as the greater one" do
        expect(operator).to eq(">")
      end
    end

    context "when the direction sorts descending" do
      let(:declaration) { :desc }

      it "compares a later row as the smaller one" do
        expect(operator).to eq("<")
      end
    end
  end

  describe "#other_way" do
    subject(:other_way) { direction.other_way }

    context "when the direction sorts ascending" do
      it "returns desc" do
        expect(other_way).to eq(:desc)
      end
    end

    context "when the direction sorts descending" do
      let(:declaration) { :desc }

      it "returns asc" do
        expect(other_way).to eq(:asc)
      end
    end
  end

  describe "#nulls_first?" do
    context "when the direction sorts ascending" do
      it { is_expected.not_to be_nulls_first }
    end

    context "when the direction sorts descending" do
      let(:declaration) { :desc }

      it { is_expected.to be_nulls_first }
    end
  end

  describe "#==" do
    context "when the other direction sorts the same way" do
      it "equals the other direction" do
        expect(direction).to eq(described_class.for(:asc))
      end

      it "counts the two directions as one value" do
        expect([described_class.for(:asc), described_class.for(:asc)].uniq).to contain_exactly(
          direction,
        )
      end
    end

    context "when the other direction sorts the other way" do
      it "differs from the other direction" do
        expect(direction).not_to eq(described_class.for(:desc))
      end
    end
  end
end
